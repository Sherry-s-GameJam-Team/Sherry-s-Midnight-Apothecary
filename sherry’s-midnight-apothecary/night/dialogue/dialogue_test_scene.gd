extends Control

const BALLOON_SCENE := preload("res://night/dialogue/apothecary_balloon.tscn")
const TEST_DIALOGUE := preload("res://night/dialogue/apothecary_test.dialogue")

@export var auto_start := true
@onready var status_label: Label = %StatusLabel
@onready var pause_menu: PauseMenu = %PauseMenu
var _balloon: ApothecaryDialogueBalloon


func _ready() -> void:
	if auto_start:
		call_deferred("_start_test_dialogue")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not pause_menu.visible:
		pause_menu.open()
		get_viewport().set_input_as_handled()


func _start_test_dialogue() -> void:
	if is_instance_valid(_balloon):
		_balloon.queue_free()
	_balloon = DialogueManager.show_dialogue_balloon_scene(
		BALLOON_SCENE,
		TEST_DIALOGUE,
		"start"
	) as ApothecaryDialogueBalloon
	_balloon.load_requested.connect(_on_load_requested)
	status_label.text = "Dialogue Manager 3 已启动自定义对话框"


func _on_load_requested() -> void:
	status_label.text = "测试场景已收到 load_requested 信号"
