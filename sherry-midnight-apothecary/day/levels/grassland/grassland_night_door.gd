class_name GrasslandNightDoor
extends DoorPortal

const MIASMA_CLEARED_FLAG := "emerald_field_miasma_cleared"
const GRASSLAND_HOUND_DIALOGUE_SEEN_FLAG := "grassland_hound_dialogue_seen"

@export_multiline var night_warning := "进入药水铺将开启晚间营业，请确保资源收集完毕"

var _confirmation: ConfirmationDialog
var _sleeping_hound: SleepingHoundNPC


func _ready() -> void:
	super()
	_sleeping_hound = get_parent().get_node_or_null("SleepingHoundNPC") as SleepingHoundNPC
	if _sleeping_hound != null and not _sleeping_hound.dialogue_completed.is_connected(_on_hound_dialogue_completed):
		_sleeping_hound.dialogue_completed.connect(_on_hound_dialogue_completed)
	if _task_completed():
		interaction_hint_text = "按[E]结束探索"


func _input(event: InputEvent) -> void:
	if _requires_hound_dialogue() and _player_is_inside and _is_interact_event(event):
		get_viewport().set_input_as_handled()
		_show_interaction_hint()
		return
	if not _task_completed():
		super(event)
		return
	if get_tree().has_meta("day_modal_input_locked") or not _player_is_inside or not _is_interact_event(event):
		return
	get_viewport().set_input_as_handled()
	_show_night_confirmation()


func _show_night_confirmation() -> void:
	if is_instance_valid(_confirmation):
		return
	get_tree().set_meta("day_modal_input_locked", true)
	_confirmation = ConfirmationDialog.new()
	_confirmation.title = "结束探索"
	_confirmation.dialog_text = night_warning
	_confirmation.ok_button_text = "进入晚间营业"
	_confirmation.cancel_button_text = "继续收集"
	_confirmation.min_size = Vector2i(520, 220)
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
	if runtime == null or not runtime.has_method("finish_day"):
		_close_confirmation()
		return
	var result := DayResult.new()
	result.completed = true
	var data := runtime.call("get_player_data") as PlayerData
	if data != null:
		result.remaining_health = data.health
	_close_confirmation()
	runtime.call("finish_day", result)


func _task_completed() -> bool:
	var runtime := _find_day_runtime()
	if runtime == null or not runtime.has_method("get_player_data"):
		return false
	var data := runtime.call("get_player_data") as PlayerData
	return data != null and bool(data.tutorial_flags.get(MIASMA_CLEARED_FLAG, false))


func is_locked_for_hound_dialogue() -> bool:
	return _requires_hound_dialogue()


func _requires_hound_dialogue() -> bool:
	var runtime := _find_day_runtime()
	var current_day := int(runtime.get("day")) if runtime != null else 0
	if current_day != 0:
		return false
	var data_provider: Node = runtime if runtime != null else get_parent()
	var data := data_provider.call("get_player_data") as PlayerData if data_provider != null and data_provider.has_method("get_player_data") else null
	return data != null and not bool(data.tutorial_flags.get(GRASSLAND_HOUND_DIALOGUE_SEEN_FLAG, false))


func _on_hound_dialogue_completed() -> void:
	if _player_is_inside:
		_show_interaction_hint()


func _show_interaction_hint() -> void:
	if _requires_hound_dialogue():
		var top_hint := _find_top_hint()
		if top_hint != null:
			top_hint.show_interaction_hint(_hint_id(), "先按[E]与沉睡的魔犬交谈")
		return
	super()
