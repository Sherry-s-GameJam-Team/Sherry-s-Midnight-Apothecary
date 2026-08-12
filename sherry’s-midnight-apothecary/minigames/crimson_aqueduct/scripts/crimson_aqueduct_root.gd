class_name CrimsonAqueductRoot
extends Control

signal minigame_completed(result: Dictionary)
signal minigame_failed(result: Dictionary)
signal minigame_exited()

const VALVE_SCENE := preload("res://minigames/crimson_aqueduct/scenes/interactables/valve_interactable.tscn")
const DEFAULT_CONFIG := {
	"level_id": &"standard",
	"safe_pollution_threshold": 0.12,
	"minimum_clean_supply": 0.25,
	"minimum_pressure": 0.30,
	"maximum_pressure": 0.85,
	"stability_duration": 8.0,
}

var config := DEFAULT_CONFIG.duplicate(true)
var stability_time := 0.0
var operation_count := 0
var _finished := false

@onready var pipe_network: PipeNetwork = %PipeNetwork
@onready var pipe_view: PipeNetworkView = %PipeNetworkView
@onready var valve_layer: Control = %ValveLayer
@onready var reservoir_display: ReservoirDisplay = %ReservoirDisplay
@onready var hud: UIHud = %UIHud


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.exit_requested.connect(func() -> void: minigame_exited.emit())
	_apply_config(config)


func setup(new_config: Dictionary) -> void:
	config = _sanitize_config(new_config)
	if is_node_ready():
		_apply_config(config)


func _process(delta: float) -> void:
	if _finished or not is_node_ready():
		return
	pipe_network.advance(delta)
	var snapshot := pipe_network.get_snapshot()
	var pollution: float = snapshot["reservoir_pollution"]
	var supply: float = snapshot["clean_supply"]
	var pressure: float = snapshot["pressure"]
	var safe := pollution <= float(config["safe_pollution_threshold"]) \
		and supply >= float(config["minimum_clean_supply"]) \
		and pressure >= float(config["minimum_pressure"]) \
		and pressure <= float(config["maximum_pressure"])
	stability_time = minf(stability_time + delta, float(config["stability_duration"])) if safe else 0.0
	pipe_view.update_flows(snapshot["connections"])
	reservoir_display.update_display(
		pollution,
		supply,
		pressure,
		stability_time / float(config["stability_duration"]),
		config
	)
	hud.update_status(config["level_id"], safe)
	if stability_time >= float(config["stability_duration"]):
		_complete()


func _sanitize_config(new_config: Dictionary) -> Dictionary:
	var result := DEFAULT_CONFIG.duplicate(true)
	for key: String in DEFAULT_CONFIG:
		if new_config.has(key):
			result[key] = new_config[key]
	var requested := StringName(str(result["level_id"]))
	result["level_id"] = requested if PipeNetwork.LEVEL_IDS.has(requested) else &"standard"
	result["safe_pollution_threshold"] = clampf(float(result["safe_pollution_threshold"]), 0.0, 1.0)
	result["minimum_clean_supply"] = clampf(float(result["minimum_clean_supply"]), 0.0, 1.0)
	result["minimum_pressure"] = clampf(float(result["minimum_pressure"]), 0.0, 1.0)
	result["maximum_pressure"] = clampf(float(result["maximum_pressure"]), float(result["minimum_pressure"]), 1.0)
	result["stability_duration"] = maxf(float(result["stability_duration"]), 0.1)
	return result


func _apply_config(value: Dictionary) -> void:
	config = _sanitize_config(value)
	stability_time = 0.0
	operation_count = 0
	_finished = false
	pipe_network.configure(config["level_id"])
	pipe_view.configure(pipe_network.get_level_layout())
	_build_valves()
	hud.update_status(config["level_id"], false)


func _build_valves() -> void:
	for child in valve_layer.get_children():
		valve_layer.remove_child(child)
		child.queue_free()
	for data: Dictionary in pipe_network.valve_definitions:
		var valve := VALVE_SCENE.instantiate() as ValveInteractable
		valve_layer.add_child(valve)
		valve.configure(data)
		valve.state_changed.connect(_on_valve_state_changed)


func _on_valve_state_changed(valve_id: StringName, state: int) -> void:
	if _finished:
		return
	operation_count += 1
	stability_time = 0.0
	pipe_network.set_valve_state(valve_id, state)


func _complete() -> void:
	if _finished:
		return
	_finished = true
	pipe_network.running = false
	for child in valve_layer.get_children():
		(child as Button).disabled = true
	minigame_completed.emit(_build_result())


func _build_result() -> Dictionary:
	var snapshot := pipe_network.get_snapshot()
	var score := maxi(0, 1600 - operation_count * 20 + int((1.0 - float(snapshot["reservoir_pollution"])) * 400.0))
	return {
		"level_id": config["level_id"],
		"reason": &"water_secured",
		"reservoir_pollution": snapshot["reservoir_pollution"],
		"clean_supply": snapshot["clean_supply"],
		"pressure": snapshot["pressure"],
		"valve_states": pipe_network.get_valve_states(),
		"operation_count": operation_count,
		"score": score,
	}
