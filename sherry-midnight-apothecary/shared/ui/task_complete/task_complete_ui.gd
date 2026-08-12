class_name TaskCompleteUI
extends CanvasLayer

signal presented(task_title: String)
signal dismissed

@export_range(0.0, 3.0, 0.05) var minimum_display_seconds := 0.8

@onready var overlay: Control = %Overlay
@onready var dimmer: ColorRect = %Dimmer
@onready var effect: TaskCompleteEffect = %TaskCompleteEffect
@onready var panel: PanelContainer = %Panel
@onready var title_label: Label = %TaskTitle
@onready var description_label: Label = %Description
@onready var footer_label: Label = %Footer
@onready var continue_button: Button = %ContinueButton
@onready var complete_chime: AudioStreamPlayer = %CompleteChime
@onready var sparkle_chime: AudioStreamPlayer = %SparkleChime

var _active := false
var _can_dismiss := false
var _modal_lock_preexisted := false
var _presentation_serial := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.hide()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	continue_button.pressed.connect(dismiss)


func _unhandled_input(event: InputEvent) -> void:
	if not _active or not _can_dismiss:
		return
	if (
		event.is_action_pressed("ui_accept")
		or event.is_action_pressed("ui_cancel")
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	):
		dismiss()
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	_restore_modal_lock()


func present(
	task_title: String,
	description: String,
	footer: String = "任务进度已记录"
) -> void:
	_presentation_serial += 1
	var serial := _presentation_serial
	_active = true
	_can_dismiss = false
	title_label.text = task_title
	description_label.text = description
	footer_label.text = footer
	continue_button.disabled = true
	overlay.show()
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	dimmer.color = Color(0.025, 0.018, 0.012, 0.0)
	panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	panel.scale = Vector2(0.72, 0.72)
	panel.pivot_offset = panel.size * 0.5
	_set_modal_lock()
	effect.play_effect()
	complete_chime.play()
	_play_sparkle_chime_later(serial)

	var tween := create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.58)
	tween.tween_property(panel, "modulate:a", 1.0, 0.24)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(dimmer, "color:a", 0.68, 0.3)
	presented.emit(task_title)
	_enable_dismiss_later(serial)


func dismiss() -> void:
	if not _active:
		return
	_active = false
	_can_dismiss = false
	_presentation_serial += 1
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	continue_button.disabled = true
	_restore_modal_lock()
	dismissed.emit()
	var tween := create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "scale", Vector2(1.06, 1.06), 0.18)
	tween.tween_property(panel, "modulate:a", 0.0, 0.18)
	tween.tween_property(dimmer, "color:a", 0.0, 0.24)
	tween.chain().tween_callback(_finish_dismiss_animation)


func is_showing() -> bool:
	return _active


func _enable_dismiss_later(serial: int) -> void:
	await get_tree().create_timer(minimum_display_seconds, true, false, true).timeout
	if serial != _presentation_serial or not _active:
		return
	_can_dismiss = true
	continue_button.disabled = false
	continue_button.grab_focus()


func _play_sparkle_chime_later(serial: int) -> void:
	await get_tree().create_timer(0.16, true, false, true).timeout
	if serial == _presentation_serial and _active:
		sparkle_chime.play()


func _finish_dismiss_animation() -> void:
	if _active:
		return
	overlay.hide()
	effect.stop_effect()
	panel.scale = Vector2.ONE


func _set_modal_lock() -> void:
	_modal_lock_preexisted = get_tree().has_meta("day_modal_input_locked")
	get_tree().set_meta("day_modal_input_locked", true)


func _restore_modal_lock() -> void:
	if get_tree() == null:
		return
	if not _modal_lock_preexisted:
		get_tree().remove_meta("day_modal_input_locked")
