class_name PipeNetwork
extends Node

signal state_updated(snapshot: Dictionary)

const LEVEL_IDS: Array[StringName] = [&"tutorial", &"standard", &"hard"]
const STEP := 0.1
const STATE_OPENNESS := [1.0, 0.5, 0.0]

var level_id: StringName = &"standard"
var node_definitions: Dictionary = {}
var connections: Array[Dictionary] = []
var valve_definitions: Array[Dictionary] = []
var valve_states: Dictionary = {}
var node_states: Dictionary = {}
var connection_states: Array[Dictionary] = []
var reservoir_pollution := 0.0
var clean_supply := 0.0
var reservoir_pressure := 0.0
var running := true
var _accumulator := 0.0


func configure(requested_level: StringName) -> void:
	level_id = requested_level if LEVEL_IDS.has(requested_level) else &"standard"
	_build_level(level_id)
	reset()


func reset() -> void:
	_accumulator = 0.0
	reservoir_pollution = 0.48
	clean_supply = 0.08
	reservoir_pressure = 0.12
	node_states.clear()
	for node_id: StringName in node_definitions:
		node_states[node_id] = {"clean": 0.0, "pollution": 0.0, "pressure": 0.0}
	connection_states.clear()
	for connection in connections:
		connection_states.append({"flow": 0.0, "pollution": 0.0})
	running = true


func advance(delta: float) -> void:
	if not running:
		return
	_accumulator += maxf(delta, 0.0)
	while _accumulator >= STEP:
		_accumulator -= STEP
		_simulate_step()
	state_updated.emit(get_snapshot())


func set_valve_state(valve_id: StringName, state: int) -> void:
	if valve_states.has(valve_id):
		valve_states[valve_id] = clampi(state, 0, 2)


func get_valve_state(valve_id: StringName) -> int:
	return int(valve_states.get(valve_id, 0))


func get_valve_states() -> Dictionary:
	return valve_states.duplicate(true)


func get_snapshot() -> Dictionary:
	return {
		"reservoir_pollution": reservoir_pollution,
		"clean_supply": clean_supply,
		"pressure": reservoir_pressure,
		"connections": connection_states.duplicate(true),
	}


func get_level_layout() -> Dictionary:
	return {
		"nodes": node_definitions.duplicate(true),
		"connections": connections.duplicate(true),
		"valves": valve_definitions.duplicate(true),
	}


func settle(steps := 180) -> Dictionary:
	for index in steps:
		_simulate_step()
	return get_snapshot()


func _simulate_step() -> void:
	var next: Dictionary = {}
	for node_id: StringName in node_definitions:
		next[node_id] = {"clean": 0.0, "pollution": 0.0, "pressure": 0.0}

	for node_id: StringName in node_definitions:
		var definition: Dictionary = node_definitions[node_id]
		if definition.has("source_clean") or definition.has("source_pollution"):
			next[node_id]["clean"] = float(definition.get("source_clean", 0.0))
			next[node_id]["pollution"] = float(definition.get("source_pollution", 0.0))
			next[node_id]["pressure"] = float(definition.get("source_pressure", 1.0))

	var new_connection_states: Array[Dictionary] = []
	for connection: Dictionary in connections:
		var source: Dictionary = node_states[connection["from"]]
		var total: float = float(source["clean"]) + float(source["pollution"])
		var openness: float = float(STATE_OPENNESS[int(valve_states[connection["valve"]])])
		var capacity: float = float(connection["capacity"]) * openness
		var flow := minf(total, capacity) * clampf(float(source["pressure"]), 0.0, 1.2)
		var pollution_ratio := float(source["pollution"]) / maxf(total, 0.001)
		var destination: Dictionary = next[connection["to"]]
		destination["clean"] += flow * (1.0 - pollution_ratio)
		destination["pollution"] += flow * pollution_ratio
		destination["pressure"] = maxf(float(destination["pressure"]), float(source["pressure"]) * float(connection.get("pressure_retention", 0.88)) * openness)
		new_connection_states.append({"flow": flow, "pollution": pollution_ratio})

	for node_id: StringName in node_definitions:
		var old: Dictionary = node_states[node_id]
		var incoming: Dictionary = next[node_id]
		old["clean"] = lerpf(float(old["clean"]), float(incoming["clean"]), 0.34)
		old["pollution"] = lerpf(float(old["pollution"]), float(incoming["pollution"]), 0.34)
		old["pressure"] = lerpf(float(old["pressure"]), float(incoming["pressure"]), 0.3)
		node_states[node_id] = old
	connection_states = new_connection_states

	var reservoir: Dictionary = node_states[&"reservoir"]
	var reservoir_total: float = float(reservoir["clean"]) + float(reservoir["pollution"])
	var target_pollution := float(reservoir["pollution"]) / maxf(reservoir_total, 0.001)
	var target_supply := clampf(float(reservoir["clean"]) / 1.35, 0.0, 1.0)
	var target_pressure := clampf(float(reservoir["pressure"]), 0.0, 1.0)
	reservoir_pollution = lerpf(reservoir_pollution, target_pollution, 0.055)
	clean_supply = lerpf(clean_supply, target_supply, 0.07)
	reservoir_pressure = lerpf(reservoir_pressure, target_pressure, 0.07)


func _build_level(id: StringName) -> void:
	node_definitions.clear()
	connections.clear()
	valve_definitions.clear()
	valve_states.clear()
	var data := _tutorial_data() if id == &"tutorial" else (_hard_data() if id == &"hard" else _standard_data())
	for node: Dictionary in data["nodes"]:
		node_definitions[node["id"]] = node
	for connection: Dictionary in data["connections"]:
		connections.append(connection)
		var valve := {
			"id": connection["valve"],
			"label": connection["label"],
			"position": (node_definitions[connection["from"]]["position"] + node_definitions[connection["to"]]["position"]) * 0.5,
			"initial_state": int(connection.get("initial_state", 0)),
		}
		valve_definitions.append(valve)
		valve_states[valve["id"]] = valve["initial_state"]


func _tutorial_data() -> Dictionary:
	return {"nodes": [
		_node(&"spring", Vector2(70, 120), "清泉", 1.2, 0.0, 1.0),
		_node(&"red", Vector2(70, 350), "赤红源", 0.0, 0.9, 0.9),
		_node(&"north", Vector2(300, 120), "北汇流井"), _node(&"south", Vector2(300, 350), "南汇流井"),
		_node(&"merge", Vector2(535, 235), "古井"), _node(&"waste", Vector2(535, 430), "泄洪口"),
		_node(&"reservoir", Vector2(750, 235), "城镇水库"),
	], "connections": [
		_edge(&"spring", &"north", &"t01", "清泉闸", 1.1, 0), _edge(&"red", &"south", &"t02", "赤流闸", 0.9, 0),
		_edge(&"north", &"merge", &"t03", "北渠闸", 1.0, 0), _edge(&"south", &"merge", &"t04", "混流闸", 0.8, 0),
		_edge(&"south", &"waste", &"t05", "泄洪闸", 0.9, 2), _edge(&"merge", &"reservoir", &"t06", "城门总闸", 1.2, 1),
	]}


func _standard_data() -> Dictionary:
	return {"nodes": [
		_node(&"spring_a", Vector2(55, 85), "月泉", 1.05, 0.0, 1.0), _node(&"spring_b", Vector2(55, 300), "苔泉", 0.9, 0.0, 0.82),
		_node(&"red_a", Vector2(55, 500), "常霁林渠", 0.0, 0.92, 0.94), _node(&"red_b", Vector2(300, 535), "常霁林二渠", 0.0, 0.62, 0.75),
		_node(&"upper", Vector2(275, 105), "上层井"), _node(&"center", Vector2(300, 300), "中央井"), _node(&"lower", Vector2(300, 455), "下层井"),
		_node(&"balance", Vector2(520, 160), "平衡井"), _node(&"mix", Vector2(530, 350), "混流井"), _node(&"waste", Vector2(535, 535), "泄洪池"),
		_node(&"gate", Vector2(735, 270), "城门井"), _node(&"reservoir", Vector2(850, 270), "城镇水库"),
	], "connections": [
		_edge(&"spring_a", &"upper", &"s01", "月泉闸", 1.0, 0), _edge(&"spring_b", &"center", &"s02", "苔泉闸", 0.9, 1),
		_edge(&"red_a", &"lower", &"s03", "赤渗闸", 0.9, 0), _edge(&"red_b", &"lower", &"s04", "深红闸", 0.65, 0),
		_edge(&"upper", &"balance", &"s05", "上环闸", 0.95, 0), _edge(&"center", &"balance", &"s06", "中上闸", 0.75, 1),
		_edge(&"center", &"mix", &"s07", "中央闸", 0.9, 0), _edge(&"lower", &"mix", &"s08", "下环闸", 0.85, 0),
		_edge(&"lower", &"waste", &"s09", "下泄洪闸", 0.95, 2), _edge(&"balance", &"gate", &"s10", "净流闸", 1.05, 0),
		_edge(&"mix", &"gate", &"s11", "混流闸", 0.8, 1), _edge(&"gate", &"reservoir", &"s12", "城门总闸", 1.25, 1),
	]}


func _hard_data() -> Dictionary:
	var data := _standard_data()
	data["nodes"].append_array([
		_node(&"old_spring", Vector2(55, 205), "旧泉", 0.62, 0.0, 0.68), _node(&"seep", Vector2(520, 455), "旁路渗污", 0.0, 0.5, 0.62),
		_node(&"return", Vector2(700, 455), "回压井"), _node(&"relief", Vector2(720, 555), "泄压井"),
	])
	data["connections"].append_array([
		_edge(&"old_spring", &"center", &"h13", "旧泉闸", 0.62, 1), _edge(&"seep", &"return", &"h14", "旁渗闸", 0.5, 0),
		_edge(&"return", &"gate", &"h15", "回压闸", 0.5, 1), _edge(&"return", &"relief", &"h16", "泄压闸", 0.65, 2),
	])
	return data


func _node(id: StringName, position: Vector2, label: String, clean := -1.0, pollution := -1.0, pressure := -1.0) -> Dictionary:
	var node := {"id": id, "position": position, "label": label}
	if clean >= 0.0:
		node["source_clean"] = clean
		node["source_pollution"] = pollution
		node["source_pressure"] = pressure
	return node


func _edge(from: StringName, to: StringName, valve: StringName, label: String, capacity: float, initial_state: int) -> Dictionary:
	return {"from": from, "to": to, "valve": valve, "label": label, "capacity": capacity, "initial_state": initial_state, "pressure_retention": 0.9}
