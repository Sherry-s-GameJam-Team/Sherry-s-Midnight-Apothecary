class_name AlkeonCompletionGate
extends DoorPortal

## The restored Danxin Gate closes the daytime expedition after Alkeon is purified.
## It deliberately uses DayRuntime.finish_day() so the normal GameFlow loads Night Home.

@export_multiline var night_warning := "返回药水铺将开始晚间营业。确认已完成今天的探索后再进入。"

var _night_return_enabled := false
var _confirmation: ConfirmationDialog


func _ready() -> void:
	super()
	set_night_return_enabled(false)


func set_night_return_enabled(enabled: bool) -> void:
	_night_return_enabled = enabled
	monitoring = enabled
	visible = enabled
	if enabled:
		interaction_hint_enabled = true
		interaction_hint_text = "按[E]返回药水铺"
	else:
		_player_is_inside = false
		_hide_interaction_hint()


func _input(event: InputEvent) -> void:
	if not _night_return_enabled:
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
	_confirmation.cancel_button_text = "继续探索"
	_confirmation.min_size = Vector2i(560, 230)
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
	var player_data := runtime.call("get_player_data") as PlayerData
	if player_data != null:
		result.remaining_health = player_data.health
	_close_confirmation()
	runtime.call("finish_day", result)
