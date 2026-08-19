class_name InnerPartySwitchUI
extends CanvasLayer

## On-screen HUD for Vespervale Inner dual-character switching.
## Shows active character (Sherry / Luca), key prompt [C], and rhythm guidance.

@onready var sherry_label: Label = get_node_or_null("Panel/HBox/SherryLabel")
@onready var luca_label: Label = get_node_or_null("Panel/HBox/LucaLabel")
@onready var prompt_label: Label = get_node_or_null("Panel/HBox/PromptLabel")
@onready var rhythm_hint_label: Label = get_node_or_null("Panel/RhythmHint")

var _panel: PanelContainer


func _ready() -> void:
	layer = 15
	_build_ui_if_needed()

	var party := _find_party_controller()
	if party != null:
		party.active_character_changed.connect(_on_active_character_changed)
		_on_active_character_changed(party.active_character)

	var manager := _find_shift_manager()
	if manager != null:
		manager.dream_state_changed.connect(_on_dream_state_changed)
		_on_dream_state_changed(manager.is_in_dream())


func _build_ui_if_needed() -> void:
	if _panel != null or get_child_count() > 0:
		return

	_panel = PanelContainer.new()
	_panel.name = "PartyHUD"
	_panel.offset_left = 24.0
	_panel.offset_top = 24.0
	_panel.offset_right = 310.0
	_panel.offset_bottom = 86.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.18, 0.75)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.65, 0.45, 0.85, 0.6)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(vbox)

	var hbox := HBoxContainer.new()
	hbox.name = "HBox"
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(hbox)

	sherry_label = Label.new()
	sherry_label.name = "SherryLabel"
	sherry_label.text = "◆ 雪莉 (下层)"
	sherry_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4, 1.0))
	hbox.add_child(sherry_label)

	var sep := Label.new()
	sep.text = " | "
	sep.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 0.7))
	hbox.add_child(sep)

	luca_label = Label.new()
	luca_label.name = "LucaLabel"
	luca_label.text = "◇ 卢卡 (上层)"
	luca_label.add_theme_color_override("font_color", Color(0.65, 0.75, 0.95, 0.7))
	hbox.add_child(luca_label)

	var key_prompt := Label.new()
	key_prompt.text = " [C 切换]"
	key_prompt.add_theme_color_override("font_color", Color(0.85, 0.8, 0.9, 0.85))
	hbox.add_child(key_prompt)

	rhythm_hint_label = Label.new()
	rhythm_hint_label.name = "RhythmHint"
	rhythm_hint_label.text = "梦境态：推荐卢卡上层开路"
	rhythm_hint_label.add_theme_color_override("font_color", Color(0.8, 0.65, 1.0, 0.9))
	vbox.add_child(rhythm_hint_label)


func _on_active_character_changed(char_id: StringName) -> void:
	_build_ui_if_needed()
	var is_sherry := (char_id == &"sherry")
	if sherry_label != null:
		sherry_label.text = ("◆ " if is_sherry else "◇ ") + "雪莉 (下层)"
		sherry_label.add_theme_color_override(
			"font_color",
			Color(1.0, 0.9, 0.45, 1.0) if is_sherry else Color(0.6, 0.6, 0.65, 0.6)
		)
	if luca_label != null:
		luca_label.text = ("◆ " if not is_sherry else "◇ ") + "卢卡 (上层)"
		luca_label.add_theme_color_override(
			"font_color",
			Color(0.55, 0.85, 1.0, 1.0) if not is_sherry else Color(0.6, 0.6, 0.65, 0.6)
		)


func _on_dream_state_changed(in_dream: bool) -> void:
	_build_ui_if_needed()
	if rhythm_hint_label != null:
		if in_dream:
			rhythm_hint_label.text = "梦境态 (危险)：推荐 卢卡 上层开路/解机关"
			rhythm_hint_label.add_theme_color_override("font_color", Color(0.85, 0.6, 1.0, 0.95))
		else:
			rhythm_hint_label.text = "现实入侵 (安全)：推荐 雪莉 下层快速冲刺"
			rhythm_hint_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.4, 0.95))


func _find_party_controller() -> InnerPartyController:
	var cur: Node = self
	while cur != null:
		var party := cur.get_node_or_null("InnerPartyController") as InnerPartyController
		if party != null:
			return party
		cur = cur.get_parent()
	return null


func _find_shift_manager() -> DreamShiftManager:
	var cur: Node = self
	while cur != null:
		var mgr := cur.get_node_or_null("DreamShiftManager") as DreamShiftManager
		if mgr != null:
			return mgr
		cur = cur.get_parent()
	return null
