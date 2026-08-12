class_name PipeNetworkView
extends Control

var layout: Dictionary = {}
var connection_states: Array[Dictionary] = []
var flow_phase := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configure(new_layout: Dictionary) -> void:
	layout = new_layout
	connection_states.clear()
	queue_redraw()


func update_flows(states: Array[Dictionary]) -> void:
	connection_states = states
	queue_redraw()


func _process(delta: float) -> void:
	flow_phase = fmod(flow_phase + delta * 54.0, 10000.0)
	queue_redraw()


func _draw() -> void:
	if layout.is_empty():
		return
	var nodes: Dictionary = layout["nodes"]
	var edges: Array = layout["connections"]
	for index in edges.size():
		var edge: Dictionary = edges[index]
		var from: Vector2 = nodes[edge["from"]]["position"]
		var to: Vector2 = nodes[edge["to"]]["position"]
		var state: Dictionary = connection_states[index] if index < connection_states.size() else {"flow": 0.0, "pollution": 0.0}
		var flow: float = float(state["flow"])
		var pollution: float = float(state["pollution"])
		draw_line(from, to, Color("302a24"), 24.0, true)
		draw_line(from, to, Color("3f9fa3").lerp(Color("b42c39"), pollution), 13.0, true)
		if flow > 0.015:
			_draw_flow_arrows(from, to, flow, pollution)
	for node_id: StringName in nodes:
		var node: Dictionary = nodes[node_id]
		var position: Vector2 = node["position"]
		var source_pollution := float(node.get("source_pollution", 0.0))
		var color := Color("bd3841") if source_pollution > 0.0 else Color("82705a")
		if node.has("source_clean") and source_pollution <= 0.0:
			color = Color("5faeb0")
		draw_circle(position, 15.0, color)
		draw_circle(position, 15.0, Color("c2a56c"), false, 3.0)
		draw_string(ThemeDB.fallback_font, position + Vector2(-35, -22), str(node["label"]), HORIZONTAL_ALIGNMENT_CENTER, 70.0, 13, Color("d8c9a8"))


func _draw_flow_arrows(from: Vector2, to: Vector2, flow: float, pollution: float) -> void:
	var length := from.distance_to(to)
	if length < 36.0:
		return
	var direction := (to - from).normalized()
	var normal := Vector2(-direction.y, direction.x)
	var usable_length := length - 28.0
	var arrow_count := maxi(int(usable_length / 68.0), 1)
	var spacing := usable_length / float(arrow_count)
	var speed := lerpf(16.0, 78.0, clampf(flow / 1.1, 0.0, 1.0))
	var arrow_color := Color("d8f5e8").lerp(Color("ffd0c2"), pollution)
	for index in arrow_count:
		var distance := 14.0 + fmod(flow_phase * speed / 54.0 + float(index) * spacing, usable_length)
		var tip := from + direction * distance
		var tail := tip - direction * 15.0
		var left := tail + normal * 7.0
		var right := tail - normal * 7.0
		draw_colored_polygon(PackedVector2Array([tip, left, right]), arrow_color)
		draw_polyline(PackedVector2Array([left, tip, right]), Color(0.12, 0.1, 0.08, 0.75), 1.5, true)
