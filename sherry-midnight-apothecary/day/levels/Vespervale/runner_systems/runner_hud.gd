class_name RunnerHUD
extends CanvasLayer

## On-screen HUD for Vespervale 2-minute parkour auto-runner.
## Displays progress bar, time elapsed/remaining, dual-character jump keybinds, and completion prompt.

var _panel: PanelContainer
var _progress_bar: ProgressBar
var _time_label: Label
var _prompt_label: Label


func _ready() -> void:
	layer = 20
	_build_ui()

	var controller := _find_controller()
	if controller != null:
		controller.runner_progress_updated.connect(_on_progress_updated)
		controller.runner_finished.connect(_on_runner_finished)


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "RunnerHUDPanel"
	_panel.anchors_preset = Control.PRESET_TOP_WIDE
	_panel.offset_left = 120.0
	_panel.offset_top = 16.0
	_panel.offset_right = -120.0
	_panel.offset_bottom = 80.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.16, 0.82)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_width_bottom = 2
	style.border_color = Color(0.7, 0.45, 0.9, 0.8)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(vbox)

	var hbox_top := HBoxContainer.new()
	hbox_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(hbox_top)

	var title_lbl := Label.new()
	title_lbl.text = "梦境疾驰 · 2分钟极限跑酷"
	title_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 1.0, 1.0))
	hbox_top.add_child(title_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox_top.add_child(spacer)

	_time_label = Label.new()
	_time_label.text = "00:00 / 02:00"
	_time_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4, 1.0))
	hbox_top.add_child(_time_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(0, 10)
	_progress_bar.max_value = 120.0
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = false
	vbox.add_child(_progress_bar)

	var hbox_keys := HBoxContainer.new()
	hbox_keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(hbox_keys)

	var luca_key := Label.new()
	luca_key.text = "◇ [空格 Space] 上层卢卡跳跃"
	luca_key.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0, 0.9))
	hbox_keys.add_child(luca_key)

	var sep := Label.new()
	sep.text = "  |  "
	sep.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6, 0.6))
	hbox_keys.add_child(sep)

	var sherry_key := Label.new()
	sherry_key.text = "◆ [W 键 / ↑] 下层雪莉跳跃"
	sherry_key.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5, 0.9))
	hbox_keys.add_child(sherry_key)

	_prompt_label = Label.new()
	_prompt_label.visible = false
	_prompt_label.text = "★ 已到达终点！按 [E] 离开"
	_prompt_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5, 1.0))
	hbox_keys.add_child(_prompt_label)


func _on_progress_updated(elapsed: float, total: float) -> void:
	if _progress_bar != null:
		_progress_bar.value = elapsed
		_progress_bar.max_value = total

	if _time_label != null:
		var cur_m := int(elapsed) / 60
		var cur_s := int(elapsed) % 60
		var tot_m := int(total) / 60
		var tot_s := int(total) % 60
		_time_label.text = "%02d:%02d / %02d:%02d" % [cur_m, cur_s, tot_m, tot_s]


func _on_runner_finished() -> void:
	if _prompt_label != null:
		_prompt_label.visible = true
	if _time_label != null:
		_time_label.text = "02:00 (通关)"


func _find_controller() -> RunnerController:
	var cur: Node = self
	while cur != null:
		var ctrl := cur.get_node_or_null("RunnerController") as RunnerController
		if ctrl != null:
			return ctrl
		cur = cur.get_parent()
	return null
