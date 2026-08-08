@tool
class_name MapSwitchAnchor
extends Node2D

## Move this node in map.tscn; the map switch uses its position and fields.
@export var destination_id: StringName = &""
@export var display_name := "Unnamed Anchor"
@export var subtitle := ""
@export var danger := "UNKNOWN"
@export var distance_text := "--"
@export var environment := ""
@export_multiline var description := ""

var _candidate_strength := 0.0
var _selected := false
var _pulse_time := 0.0

func _ready() -> void:
	set_process(not Engine.is_editor_hint())
	queue_redraw()

func _process(delta: float) -> void:
	_pulse_time += delta
	queue_redraw()

func set_visual_state(candidate_strength: float, selected: bool) -> void:
	_candidate_strength = clampf(candidate_strength, 0.0, 1.0)
	_selected = selected
	queue_redraw()

func to_destination(fallback: Dictionary = {}) -> Dictionary:
	return {"id": destination_id if destination_id != &"" else fallback.get("id", StringName(name.to_snake_case())), "name": display_name if not display_name.is_empty() else fallback.get("name", name), "subtitle": subtitle if not subtitle.is_empty() else fallback.get("subtitle", ""), "pos": position, "danger": danger if not danger.is_empty() else fallback.get("danger", "UNKNOWN"), "distance": distance_text if not distance_text.is_empty() else fallback.get("distance", "--"), "environment": environment if not environment.is_empty() else fallback.get("environment", ""), "description": description if not description.is_empty() else fallback.get("description", "")}

func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_pulse_time * 4.0)
	var outer := Color(0.97, 0.72, 0.28, 0.62) if _selected else Color(0.76, 0.36, 1.0, 0.45 + _candidate_strength * 0.35) if _candidate_strength > 0.0 else Color(0.35, 0.70, 1.0, 0.32)
	var inner := Color(1.0, 0.87, 0.46, 1.0) if _selected else Color(0.86, 0.58, 1.0, 1.0) if _candidate_strength > 0.0 else Color(0.45, 0.85, 1.0, 0.95)
	draw_circle(Vector2.ZERO, 15.0 + pulse * 3.0, outer)
	draw_circle(Vector2.ZERO, 8.0, Color(0.04, 0.08, 0.16, 0.95))
	draw_circle(Vector2.ZERO, 4.5, inner)
	draw_arc(Vector2.ZERO, 11.0, _pulse_time, _pulse_time + PI * 1.35, 24, inner, 1.5)
	if Engine.is_editor_hint():
		draw_string(ThemeDB.fallback_font, Vector2(16, -10), display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.86, 0.58, 0.95))
