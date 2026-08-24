class_name VespervaleNightPortal
extends DoorPortal

## Night return portal for Vespervale Garden.
## Before boss is defeated: Portal visual is hidden.
## After boss is defeated: Displays glowing waypoint portal texture, hides NPCs, and pressing E opens confirmation to finish daytime and enter night state.

@export_multiline var night_warning := "返回药水铺将开启晚间营业。确认已完成今天的探索后再进入。"

var _confirmation: ConfirmationDialog

@onready var portal_sprite: Sprite2D = get_node_or_null("PortalVisual")


func _ready() -> void:
	super._ready()
	update_portal_state()


func update_portal_state() -> void:
	var boss_cleared := is_boss_cleared()
	if portal_sprite != null:
		portal_sprite.visible = boss_cleared
		if boss_cleared and not portal_sprite.has_meta("tween_started"):
			portal_sprite.set_meta("tween_started", true)
			var base_y := portal_sprite.position.y
			var tw := create_tween().set_loops()
			tw.tween_property(portal_sprite, "position:y", base_y - 6.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(portal_sprite, "position:y", base_y + 6.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if boss_cleared:
		interaction_hint_enabled = true
		interaction_hint_text = "按 E 返回药水铺（开启晚间营业）"
	else:
		interaction_hint_enabled = true
		interaction_hint_text = "按 E 返回雪莉药水铺"


func is_boss_cleared() -> bool:
	var runtime := _find_day_runtime()
	if runtime != null and runtime.has_method("get_player_data"):
		var data := runtime.call("get_player_data") as PlayerData
		if data != null and data.tutorial_flags != null:
			return bool(data.tutorial_flags.get("vespervale_boss_cleared", false)) or bool(data.tutorial_flags.get("vespervale_garden_cleansed", false))
	var parent_level := get_parent()
	while parent_level != null:
		if parent_level.has_method("get_player_data"):
			var data := parent_level.call("get_player_data") as PlayerData
			if data != null and data.tutorial_flags != null:
				return bool(data.tutorial_flags.get("vespervale_boss_cleared", false)) or bool(data.tutorial_flags.get("vespervale_garden_cleansed", false))
		parent_level = parent_level.get_parent()
	return false


func _input(event: InputEvent) -> void:
	if not _player_is_inside or not _is_interact_event(event):
		return
	if get_tree().has_meta("day_modal_input_locked"):
		return

	get_viewport().set_input_as_handled()

	if is_boss_cleared():
		_show_night_confirmation()
	else:
		_execute_transition()


func _show_night_confirmation() -> void:
	if is_instance_valid(_confirmation):
		return
	get_tree().set_meta("day_modal_input_locked", true)
	_confirmation = ConfirmationDialog.new()
	_confirmation.title = "结束探索"
	_confirmation.dialog_text = night_warning
	_confirmation.ok_button_text = "进入晚间营业"
	_confirmation.cancel_button_text = "继续探索"
	_confirmation.min_size = Vector2i(540, 220)
	add_child(_confirmation)
	_confirmation.confirmed.connect(_enter_night, CONNECT_ONE_SHOT)
	_confirmation.canceled.connect(_close_confirmation, CONNECT_ONE_SHOT)
	_confirmation.popup_centered()


func _close_confirmation() -> void:
	if is_instance_valid(_confirmation):
		_confirmation.queue_free()
	_confirmation = null
	if get_tree() != null:
		get_tree().remove_meta("day_modal_input_locked")


func _enter_night() -> void:
	var runtime := _find_day_runtime()
	if runtime != null and runtime.has_method("finish_day"):
		var result := DayResult.new()
		result.completed = true
		var player_data := runtime.call("get_player_data") as PlayerData
		if player_data != null:
			result.remaining_health = player_data.health
		_close_confirmation()
		runtime.call("finish_day", result)
		return

	# Standalone fallback:
	_close_confirmation()
	if not fallback_scene_path.is_empty():
		get_tree().change_scene_to_file(fallback_scene_path)
