class_name UIHud
extends Control

signal exit_requested

@onready var level_label: Label = %LevelLabel
@onready var state_label: Label = %StateLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	%ExitButton.pressed.connect(func() -> void: exit_requested.emit())


func update_status(level_id: StringName, safe: bool) -> void:
	level_label.text = "水渠层级：%s" % {&"tutorial": "引水廊", &"standard": "赤红主渠", &"hard": "深层旧渠"}.get(level_id, "赤红主渠")
	state_label.text = "水路已进入安全平衡，正在稳定……" if safe else "调整阀门，隔离赤红污染并维持供水与水压"
	state_label.modulate = Color("8dd8b0") if safe else Color("d8c9a8")
