class_name PipeNetwork
extends Node

signal state_updated(snapshot: Dictionary)

const FIXED_STEP := 0.1
const LEVEL_IDS: Array[StringName] = [&"tutorial", &"standard", &"hard"]

var nodes: Dictionary = {}
var connections: Array[Dictionary] = []
var valves: Dictionary = {}
var diverters: Dictionary = {}
var cracks: Dictionary = {}
var purifiers: Dictionary = {}
var level_id: StringName = &"standard"
var running := false
var reservoir_pollution := 0.0
var clean_supply := 0.0
var reservoir_pressure := 0.0
var _accumulator := 0.0


func configure(requested_level_id: StringName) -> void:
	level_id = requested_level_id if LEVEL_IDS.has(requested_level_id) else &"standard"
	_build_level(level_id)
	reset()


func reset() -> void:
	_accumulator = 0.0
	reservoir_pollution = 0.0
	clean_supply = 0.0
	reservoir_pressure = 0.0
	for node_id: StringName in nodes:
		var data: Dictionary = nodes[node_id]
		data["clean"] = 0.0
		data["pollution"] = 0.0
		data["pressure"] = 0.0
		nodes[node_id] = data
	for purifier_id: StringName in purifiers:
		purifiers[purifier_id]["remaining"] = 0.0
	for crack_id: StringName in cracks:
		cracks[crack_id]["sealed"] = false
	running = true


func advance(delta: float) -> void:
	if not running:
		return
	_accumulator += maxf(delta, 0.0)
	while _accumulator >= FIXED_STEP:
		_accumulator -= FIXED_STEP
		_simulate_step(FIXED_STEP)
	state_updated.emit(get_snapshot())


func set_valve_state(valve_id: StringName, openness: float) -> void:
	if valves.has(valve_id):
		valves[valve_id] = clampf(openness, 0.0, 1.0)


func set_diverter_direction(diverter_id: StringName, direction: int) -> void:
	if diverters.has(diverter_id):
		diverters[diverter_id] = clampi(direction, 0, 1)


func activate_purifier(purifier_id: StringName, duration := 8.0) -> bool:
	if not purifiers.has(purifier_id):
		return false
	purifiers[purifier_id]["remaining"] = maxf(duration, 0.1)
	return true


func seal_crack(crack_id: StringName) -> bool:
	if not cracks.has(crack_id) or bool(cracks[crack_id].get("sealed", false)):
		return false
	cracks[crack_id]["sealed"] = true
	return true


func get_snapshot() -> Dictionary:
	return {
		"reservoir_pollution": reservoir_pollution,
		"clean_supply": clean_supply,
		"pressure": reservoir_pressure,
	}


func _simulate_step(delta: float) -> void:
	var next: Dictionary = {}
	for node_id: StringName in nodes:
		next[node_id] = {"clean": 0.0, "pollution": 0.0, "pressure": 0.0}

	_inject(next, &"spring", 1.15, 0.0, 1.0)
	_inject(next, &"corruption", 0.05, 1.2, 0.9)
	for crack_id: StringName in cracks:
		var crack: Dictionary = cracks[crack_id]
		if not bool(crack.get("sealed", false)):
			_inject(next, crack["node"], 0.0, float(crack["rate"]), 0.45)

	for connection: Dictionary in connections:
		var from_id: StringName = connection["from"]
		var to_id: StringName = connection["to"]
		var source: Dictionary = nodes[from_id]
		var openness := 1.0
		var valve_id: StringName = connection.get("valve", &"")
		if valve_id != &"":
			openness *= float(valves.get(valve_id, 1.0))
		var diverter_id: StringName = connection.get("diverter", &"")
		if diverter_id != &"":
			var active_branch := int(diverters.get(diverter_id, 0))
			openness *= 0.92 if active_branch == int(connection.get("branch", 0)) else 0.08
		var capacity: float = float(connection.get("capacity", 1.0)) * openness
		var transfer := minf(capacity, float(source["clean"]) + float(source["pollution"]))
		var total := maxf(float(source["clean"]) + float(source["pollution"]), 0.001)
		var pressure_factor := clampf(float(source["pressure"]), 0.1, 1.0)
		transfer *= pressure_factor
		var clean_out := transfer * float(source["clean"]) / total
		var pollution_out := transfer * float(source["pollution"]) / total
		_inject(next, to_id, clean_out, pollution_out, pressure_factor * 0.91)

	for purifier_id: StringName in purifiers:
		var purifier: Dictionary = purifiers[purifier_id]
		var remaining: float = maxf(float(purifier["remaining"]) - delta, 0.0)
		purifier["remaining"] = remaining
		purifiers[purifier_id] = purifier
		if remaining > 0.0:
			var node_id: StringName = purifier["node"]
			var removed: float = float(next[node_id]["pollution"]) * 0.72
			next[node_id]["pollution"] -= removed
			next[node_id]["clean"] += removed * 0.35

	for node_id: StringName in nodes:
		var old: Dictionary = nodes[node_id]
		var incoming: Dictionary = next[node_id]
		old["clean"] = lerpf(float(old["clean"]), float(incoming["clean"]), 0.42)
		old["pollution"] = lerpf(float(old["pollution"]), float(incoming["pollution"]), 0.42)
		old["pressure"] = lerpf(float(old["pressure"]), float(incoming["pressure"]), 0.38)
		nodes[node_id] = old

	var reservoir: Dictionary = nodes[&"reservoir"]
	var total_water: float = float(reservoir["clean"]) + float(reservoir["pollution"])
	var incoming_ratio := float(reservoir["pollution"]) / maxf(total_water, 0.001)
	reservoir_pollution = clampf(lerpf(reservoir_pollution, incoming_ratio, 0.045), 0.0, 1.0)
	clean_supply = clampf(float(reservoir["clean"]) / 1.15, 0.0, 1.0)
	reservoir_pressure = clampf(float(reservoir["pressure"]), 0.0, 1.0)


func _inject(target: Dictionary, node_id: StringName, clean: float, pollution: float, pressure: float) -> void:
	if not target.has(node_id):
		return
	target[node_id]["clean"] += clean
	target[node_id]["pollution"] += pollution
	target[node_id]["pressure"] = maxf(float(target[node_id]["pressure"]), pressure)


func _build_level(id: StringName) -> void:
	nodes.clear()
	connections.clear()
	valves.clear()
	diverters.clear()
	cracks.clear()
	purifiers.clear()
	var node_ids: Array[StringName] = [&"spring", &"corruption", &"junction", &"purifier", &"waste", &"bypass", &"reservoir"]
	if id == &"hard":
		node_ids.append(&"lower_channel")
	for node_id: StringName in node_ids:
		nodes[node_id] = {"clean": 0.0, "pollution": 0.0, "pressure": 0.0}
	valves = {&"spring_gate": 1.0, &"red_gate": 1.0, &"town_gate": 1.0}
	diverters = {&"main_diverter": 0}
	purifiers = {&"purifier_basin": {"node": &"purifier", "remaining": 0.0}}
	cracks = {&"upper_crack": {"node": &"junction", "rate": 0.36, "sealed": false}}
	connections = [
		{"from": &"spring", "to": &"junction", "capacity": 1.0, "valve": &"spring_gate"},
		{"from": &"corruption", "to": &"junction", "capacity": 0.9, "valve": &"red_gate"},
		{"from": &"junction", "to": &"purifier", "capacity": 1.0, "diverter": &"main_diverter", "branch": 0},
		{"from": &"junction", "to": &"waste", "capacity": 1.0, "diverter": &"main_diverter", "branch": 1},
		{"from": &"purifier", "to": &"reservoir", "capacity": 1.0, "valve": &"town_gate"},
	]
	if id != &"tutorial":
		connections.append({"from": &"corruption", "to": &"bypass", "capacity": 0.38})
		connections.append({"from": &"bypass", "to": &"reservoir", "capacity": 0.38})
		cracks[&"bypass_crack"] = {"node": &"bypass", "rate": 0.28, "sealed": false}
	if id == &"hard":
		connections.append({"from": &"spring", "to": &"lower_channel", "capacity": 0.32})
		connections.append({"from": &"lower_channel", "to": &"reservoir", "capacity": 0.32})
		cracks[&"lower_crack"] = {"node": &"lower_channel", "rate": 0.3, "sealed": false}
