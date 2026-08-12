class_name ValveInteractable
extends Button

signal state_changed(valve_id: StringName, state: int)

enum ValveState { OPEN, HALF, CLOSED }

@export var valve_id: StringName
@export var valve_label := "阀门"
var state := ValveState.OPEN


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pressed.connect(cycle_state)
	_refresh()


func configure(data: Dictionary) -> void:
	valve_id = data["id"]
	valve_label = str(data["label"])
	state = clampi(int(data.get("initial_state", 0)), 0, 2) as ValveState
	position = Vector2(data["position"]) - size * 0.5
	_refresh()


func cycle_state() -> void:
	if disabled:
		return
	state = ((int(state) + 1) % ValveState.size()) as ValveState
	_refresh()
	state_changed.emit(valve_id, int(state))


func set_state(value: int) -> void:
	state = clampi(value, 0, 2) as ValveState
	_refresh()


func get_openness() -> float:
	return [1.0, 0.5, 0.0][state]


func _refresh() -> void:
	text = "%s\n%s" % [valve_label, ["开启", "半开", "关闭"][state]]
	modulate = [Color("9bcbb1"), Color("d2b36b"), Color("bd6662")][state]
	tooltip_text = "左键切换：开启 / 半开 / 关闭"
