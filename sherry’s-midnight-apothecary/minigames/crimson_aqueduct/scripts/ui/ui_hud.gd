class_name UIHud
extends Control

signal potion_mode_requested(mode: StringName)
signal exit_requested

@onready var level_label: Label = %LevelLabel
@onready var mode_label: Label = %ModeLabel
@onready var purifier_button: Button = %PurifierButton
@onready var sealant_button: Button = %SealantButton
@onready var feedback_label: Label = %FeedbackLabel

var _feedback_time := 0.0


func _ready() -> void:
	purifier_button.pressed.connect(func() -> void: potion_mode_requested.emit(&"purifier"))
	sealant_button.pressed.connect(func() -> void: potion_mode_requested.emit(&"sealant"))
	%ExitButton.pressed.connect(func() -> void: exit_requested.emit())


func _process(delta: float) -> void:
	if _feedback_time > 0.0:
		_feedback_time -= delta
		if _feedback_time <= 0.0:
			feedback_label.text = ""


func update_status(level_id: StringName, purifier_count: int, sealant_count: int, mode: StringName) -> void:
	level_label.text = "水渠层级：%s" % _level_name(level_id)
	purifier_button.text = "净化药剂  ×%d" % purifier_count
	sealant_button.text = "封堵药剂  ×%d" % sealant_count
	purifier_button.button_pressed = mode == &"purifier"
	sealant_button.button_pressed = mode == &"sealant"
	mode_label.text = "当前：%s" % {&"purifier": "净化药剂", &"sealant": "封堵药剂"}.get(mode, "徒手操作")


func show_feedback(message: String, danger := false) -> void:
	feedback_label.text = message
	feedback_label.modulate = Color("ff8e83") if danger else Color("a9e7cf")
	_feedback_time = 2.4


func set_interaction_enabled(value: bool) -> void:
	purifier_button.disabled = not value
	sealant_button.disabled = not value


func _level_name(id: StringName) -> String:
	return {&"tutorial": "引水廊", &"standard": "赤红主渠", &"hard": "深层旧渠"}.get(id, "赤红主渠")
