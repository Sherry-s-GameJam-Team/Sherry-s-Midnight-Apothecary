extends Node2D

const MESSAGES: Array[String] = [
	"按下 E 调查月光药柜",
	"获得了 3 瓶银叶露",
	"靠近坩埚后按下 E 开始调配",
	"月光正在变弱，先回到店内吧",
]

@onready var reminder: CanvasLayer = $OperationReminder
@onready var timer: Timer = $Timer

var _message_index: int = 0


func _ready() -> void:
	timer.timeout.connect(_show_next_message)
	timer.start()
	_show_next_message()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_SPACE:
			_show_next_message()
			get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0.055, 0.052, 0.075), true)
	for i in range(12):
		var y: float = 118.0 + float(i) * 46.0
		var alpha: float = 0.10 + float(i % 3) * 0.035
		draw_line(Vector2(0.0, y), Vector2(get_viewport_rect().size.x, y - 24.0), Color(0.32, 0.42, 0.39, alpha), 2.0, true)


func _show_next_message() -> void:
	reminder.call("show_reminder", MESSAGES[_message_index], 1.35)
	_message_index = (_message_index + 1) % MESSAGES.size()
