extends Node2D
class_name MagicMapCanvas

signal candidate_changed(index: int, strength: float)

const VIEW_SIZE := Vector2(512.0, 512.0)
const CENTER := VIEW_SIZE * 0.5
## Screen-space correction: this transform maps +X/-Y to visible left/down.
const ANCHOR_ALIGNMENT_OFFSET := Vector2(3.0, -3.0)
const MAGNET_PULL_MIN := 0.015
const MAGNET_PULL_MAX := 0.040

@onready var map_scene: Node2D = $Map

@export_range(0.5, 4.0, 0.05) var map_zoom := 2.0:
	set(value):
		map_zoom = clampf(value, 0.5, 4.0)
		_apply_map_transform()

var destinations: Array = []
var pan_offset := Vector2.ZERO:
	set(value):
		pan_offset = value
		_apply_map_transform()
var candidate_index := -1
var candidate_strength := 0.0
var selected_index := -1
var dragging := false
var anchors: Array[MapSwitchAnchor] = []

func _ready() -> void:
	for child in $Map/AnchorPoints.get_children():
		if child is MapSwitchAnchor:
			anchors.append(child)
	_apply_map_transform()
	set_process(true)
	queue_redraw()

## Reads the authored map anchors in their scene-tree order. Existing data only
## supplies fallback metadata while the anchor position is always authoritative.
func get_authored_destinations(fallback_destinations: Array) -> Array:
	var result: Array = []
	for index in anchors.size():
		var fallback: Dictionary = fallback_destinations[index] if index < fallback_destinations.size() else {}
		result.append(anchors[index].to_destination(fallback))
	return result

func set_destinations(data: Array) -> void:
	destinations = data.duplicate(true)
	reset_map()

func reset_map() -> void:
	pan_offset = _pan_to_center(anchors[0].position) if not anchors.is_empty() else Vector2.ZERO
	candidate_index = -1
	candidate_strength = 0.0
	selected_index = -1
	dragging = false
	_refresh_anchor_visuals()
	candidate_changed.emit(-1, 0.0)

func begin_drag() -> void:
	dragging = true

func zoom_by(factor: float) -> void:
	var previous_zoom := map_zoom
	map_zoom *= factor
	# Zoom around the viewport's circular center, not the current pan origin.
	if previous_zoom > 0.0:
		pan_offset *= map_zoom / previous_zoom

func pan_by_keyboard(direction: Vector2, delta: float, speed: float) -> void:
	if direction.is_zero_approx():
		return
	pan_offset += direction.normalized() * speed * delta
	_update_magnetic_candidate()

func drag_by(delta_in_viewport: Vector2, magnetic_radius: float = 92.0) -> void:
	if not dragging:
		return
	pan_offset += delta_in_viewport
	_update_magnetic_candidate(magnetic_radius)

func _update_magnetic_candidate(magnetic_radius: float = 92.0) -> void:
	var nearest := get_nearest_destination()
	candidate_index = int(nearest["index"])
	candidate_strength = 0.0
	if candidate_index >= 0 and float(nearest["distance"]) < magnetic_radius:
		candidate_strength = 1.0 - float(nearest["distance"]) / magnetic_radius
		pan_offset -= (nearest["screen_position"] as Vector2 - _selection_target()) * lerpf(MAGNET_PULL_MIN, MAGNET_PULL_MAX, candidate_strength)
	_refresh_anchor_visuals()
	candidate_changed.emit(candidate_index, candidate_strength)

func end_drag(snap_radius: float = 108.0) -> int:
	dragging = false
	var nearest := get_nearest_destination()
	if int(nearest["index"]) >= 0 and float(nearest["distance"]) <= snap_radius:
		return int(nearest["index"])
	candidate_index = -1
	candidate_strength = 0.0
	_refresh_anchor_visuals()
	candidate_changed.emit(-1, 0.0)
	return -1

func snap_to(index: int, duration: float = 0.24) -> void:
	if index < 0 or index >= destinations.size():
		return
	selected_index = index
	candidate_index = index
	candidate_strength = 1.0
	var target_pan := _pan_to_center(destinations[index].get("pos", CENTER) as Vector2)
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "pan_offset", target_pan, duration)
	tween.finished.connect(func() -> void:
		_refresh_anchor_visuals()
	)

func get_nearest_destination() -> Dictionary:
	var result := {"index": -1, "distance": INF, "screen_position": CENTER}
	for i in destinations.size():
		var screen_pos := _destination_screen_position(i)
		var distance := screen_pos.distance_to(_selection_target())
		if distance < float(result["distance"]):
			result = {"index": i, "distance": distance, "screen_position": screen_pos}
	return result

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color("10172d"))
	var grid_color := Color(0.25, 0.58, 0.78, 0.10)
	for x in range(-128, 700, 64):
		var px := fposmod(float(x) + pan_offset.x * 0.22, 640.0) - 64.0
		draw_line(Vector2(px, 0), Vector2(px, VIEW_SIZE.y), grid_color, 1.0)
	for y in range(-128, 700, 64):
		var py := fposmod(float(y) + pan_offset.y * 0.22, 640.0) - 64.0
		draw_line(Vector2(0, py), Vector2(VIEW_SIZE.x, py), grid_color, 1.0)

func _destination_screen_position(index: int) -> Vector2:
	return CENTER + pan_offset + ((destinations[index].get("pos", CENTER) as Vector2) - CENTER) * map_zoom

func _apply_map_transform() -> void:
	if is_instance_valid(map_scene):
		map_scene.scale = Vector2.ONE * map_zoom
		map_scene.position = CENTER + pan_offset - CENTER * map_zoom
	queue_redraw()

func _pan_to_center(map_position: Vector2) -> Vector2:
	return (_selection_target() - map_position) * map_zoom

func _selection_target() -> Vector2:
	return CENTER + ANCHOR_ALIGNMENT_OFFSET

func _refresh_anchor_visuals() -> void:
	for index in anchors.size():
		anchors[index].set_visual_state(candidate_strength if index == candidate_index else 0.0, index == selected_index)
