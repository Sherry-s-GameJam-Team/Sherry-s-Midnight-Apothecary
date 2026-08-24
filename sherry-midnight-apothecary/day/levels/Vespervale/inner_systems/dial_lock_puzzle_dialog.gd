class_name DialLockPuzzleDialog
extends CanvasLayer

## 4-Dial Symbol Lock Puzzle Dialog for Vespervale Inner (wall1 unlock).
## Dial patterns: bell (钟), eye (眼), moon (月), feather (羽).
## Correct password combination: [bell, eye, moon, feather] (钟眼月羽).

signal lock_unlocked
signal dialog_closed

enum SymbolType {
	BELL = 0,    # 钟
	EYE = 1,     # 眼
	MOON = 2,    # 月
	FEATHER = 3  # 羽
}

const SYMBOL_TEXTURES: Dictionary = {
	SymbolType.BELL: preload("res://day/levels/Vespervale/src/key/bell.png"),
	SymbolType.EYE: preload("res://day/levels/Vespervale/src/key/eye.png"),
	SymbolType.MOON: preload("res://day/levels/Vespervale/src/key/moon.png"),
	SymbolType.FEATHER: preload("res://day/levels/Vespervale/src/key/feather.png")
}

const SYMBOL_LIST: Array[SymbolType] = [
	SymbolType.BELL,
	SymbolType.EYE,
	SymbolType.MOON,
	SymbolType.FEATHER
]

## Correct password is 钟 (BELL), 眼 (EYE), 月 (MOON), 羽 (FEATHER)
const TARGET_COMBINATION: Array[SymbolType] = [
	SymbolType.BELL,
	SymbolType.EYE,
	SymbolType.MOON,
	SymbolType.FEATHER
]

@export var is_unlocked: bool = false

## Current dialed symbols for the 4 slots (initialized to non-matching combination)
var current_dials: Array[int] = [1, 2, 0, 1] # e.g. Eye, Moon, Bell, Eye
var _is_animating: Array[bool] = [false, false, false, false]
var _is_solved: bool = false

@onready var backdrop: ColorRect = get_node_or_null("Backdrop")
@onready var lock_frame: TextureRect = get_node_or_null("CenterContainer/LockFrame")
@onready var close_button: Button = get_node_or_null("CloseButton")
@onready var feedback_label: Label = get_node_or_null("CenterContainer/FeedbackLabel")
@onready var dial_slots: Array[Control] = [
	get_node_or_null("CenterContainer/LockFrame/Dials/Dial0") as Control,
	get_node_or_null("CenterContainer/LockFrame/Dials/Dial1") as Control,
	get_node_or_null("CenterContainer/LockFrame/Dials/Dial2") as Control,
	get_node_or_null("CenterContainer/LockFrame/Dials/Dial3") as Control
]


func _ready() -> void:
	visible = false
	if close_button != null:
		close_button.pressed.connect(close_dialog)

	_setup_dial_buttons()
	_update_all_dial_displays(true)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close_dialog()


func _setup_dial_buttons() -> void:
	for i in range(4):
		var slot := dial_slots[i]
		if slot != null:
			var btn_up := slot.get_node_or_null("BtnUp") as Button
			var btn_down := slot.get_node_or_null("BtnDown") as Button
			if btn_up != null:
				btn_up.pressed.connect(func() -> void: _rotate_dial(i, -1))
			if btn_down != null:
				btn_down.pressed.connect(func() -> void: _rotate_dial(i, 1))

			# Mouse wheel scrolling support
			slot.gui_input.connect(func(ev: InputEvent) -> void:
				if ev is InputEventMouseButton and ev.pressed:
					if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
						_rotate_dial(i, -1)
					elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
						_rotate_dial(i, 1)
			)


func open_dialog() -> void:
	if _is_solved:
		return
	visible = true
	_update_all_dial_displays(true)
	if feedback_label != null:
		feedback_label.text = "转动圆轮以解锁机关"
		feedback_label.modulate = Color(0.9, 0.85, 1.0, 0.85)

	if backdrop != null:
		backdrop.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(backdrop, "modulate:a", 0.78, 0.25)


func close_dialog() -> void:
	if backdrop != null:
		var tw := create_tween()
		tw.tween_property(backdrop, "modulate:a", 0.0, 0.2)
		tw.tween_callback(func() -> void:
			visible = false
			dialog_closed.emit()
		)
	else:
		visible = false
		dialog_closed.emit()


func _rotate_dial(slot_index: int, direction: int) -> void:
	if _is_solved or _is_animating[slot_index]:
		return

	_is_animating[slot_index] = true
	var num_symbols := SYMBOL_LIST.size()
	current_dials[slot_index] = (current_dials[slot_index] + direction + num_symbols) % num_symbols

	var slot := dial_slots[slot_index]
	if slot != null:
		var icon := slot.get_node_or_null("SymbolIcon") as TextureRect
		if icon != null:
			var target_y_out := -30.0 if direction > 0 else 30.0
			var target_y_in := 30.0 if direction > 0 else -30.0

			var tw := create_tween()
			tw.tween_property(icon, "position:y", target_y_out, 0.08)
			tw.tween_property(icon, "modulate:a", 0.1, 0.08)
			tw.tween_callback(func() -> void:
				var sym_type := SYMBOL_LIST[current_dials[slot_index]]
				icon.texture = SYMBOL_TEXTURES[sym_type]
				icon.position.y = target_y_in
			)
			tw.tween_property(icon, "position:y", 0.0, 0.12)
			tw.tween_property(icon, "modulate:a", 1.0, 0.12)
			tw.tween_callback(func() -> void:
				_is_animating[slot_index] = false
				_check_combination()
			)
	else:
		_is_animating[slot_index] = false
		_check_combination()


func _update_all_dial_displays(_instant: bool = true) -> void:
	for i in range(4):
		var slot := dial_slots[i]
		if slot != null:
			var icon := slot.get_node_or_null("SymbolIcon") as TextureRect
			if icon != null:
				var sym_type := SYMBOL_LIST[current_dials[i]]
				icon.texture = SYMBOL_TEXTURES[sym_type]
				icon.position.y = 0.0
				icon.modulate.a = 1.0


func _check_combination() -> void:
	if _is_solved:
		return

	var is_correct := true
	for i in range(4):
		if SYMBOL_LIST[current_dials[i]] != TARGET_COMBINATION[i]:
			is_correct = false
			break

	if is_correct:
		_handle_unlock_success()


func _handle_unlock_success() -> void:
	_is_solved = true
	is_unlocked = true

	if feedback_label != null:
		feedback_label.text = "✔ 密码正确！暗门机关已解除"
		feedback_label.modulate = Color(0.4, 1.0, 0.5, 1.0)

	# Flash lock frame golden/green
	if lock_frame != null:
		var tw := create_tween()
		tw.tween_property(lock_frame, "modulate", Color(1.2, 1.15, 0.8, 1.0), 0.15)
		tw.tween_property(lock_frame, "modulate", Color(0.8, 1.3, 0.9, 1.0), 0.25)
		tw.tween_property(lock_frame, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)

	# Emit unlocked signal
	lock_unlocked.emit()

	# Automatically close after short celebratory delay
	var timer := get_tree().create_timer(0.8)
	timer.timeout.connect(close_dialog)
