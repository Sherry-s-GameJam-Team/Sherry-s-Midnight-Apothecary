extends Node2D
class_name MagicMapCanvas

signal candidate_changed(index: int, strength: float)

const VIEW_SIZE := Vector2(512.0, 512.0)
const CENTER := VIEW_SIZE * 0.5

var destinations: Array = []
var pan_offset := Vector2.ZERO
var candidate_index := -1
var candidate_strength := 0.0
var selected_index := -1
var dragging := false

var _pulse_time := 0.0

func _ready() -> void:
    set_process(true)
    queue_redraw()

func set_destinations(data: Array) -> void:
    destinations = data.duplicate(true)
    queue_redraw()

func reset_map() -> void:
    pan_offset = Vector2.ZERO
    candidate_index = -1
    candidate_strength = 0.0
    selected_index = -1
    dragging = false
    candidate_changed.emit(-1, 0.0)
    queue_redraw()

func begin_drag() -> void:
    dragging = true

func drag_by(delta_in_viewport: Vector2, magnetic_radius: float = 92.0) -> void:
    if not dragging:
        return
    pan_offset += delta_in_viewport

    var nearest := get_nearest_destination()
    candidate_index = int(nearest["index"])
    candidate_strength = 0.0
    if int(nearest["index"]) >= 0 and float(nearest["distance"]) < magnetic_radius:
        candidate_strength = 1.0 - float(nearest["distance"]) / magnetic_radius
        # Progressive attraction: weak at the edge, obvious near the center.
        var node_delta: Vector2 = nearest["screen_position"] - CENTER
        pan_offset -= node_delta * (0.035 + candidate_strength * 0.12)

    candidate_changed.emit(candidate_index, candidate_strength)
    queue_redraw()

func end_drag(snap_radius: float = 108.0) -> int:
    dragging = false
    var nearest := get_nearest_destination()
    if int(nearest["index"]) >= 0 and float(nearest["distance"]) <= snap_radius:
        return int(nearest["index"])
    candidate_index = -1
    candidate_strength = 0.0
    candidate_changed.emit(-1, 0.0)
    queue_redraw()
    return -1

func snap_to(index: int, duration: float = 0.24) -> void:
    if index < 0 or index >= destinations.size():
        return
    selected_index = index
    candidate_index = index
    candidate_strength = 1.0
    var world_pos: Vector2 = destinations[index].get("pos", Vector2.ZERO)
    var target_pan := -world_pos
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "pan_offset", target_pan, duration)
    tween.parallel().tween_method(_set_candidate_strength, candidate_strength, 1.0, duration)
    tween.finished.connect(func(): queue_redraw())

func _set_candidate_strength(value: float) -> void:
    candidate_strength = value
    queue_redraw()

func get_nearest_destination() -> Dictionary:
    var result := {
        "index": -1,
        "distance": INF,
        "screen_position": CENTER,
    }
    for i in range(destinations.size()):
        var world_pos: Vector2 = destinations[i].get("pos", Vector2.ZERO)
        var screen_pos := CENTER + world_pos + pan_offset
        var dist := screen_pos.distance_to(CENTER)
        if dist < float(result["distance"]):
            result["index"] = i
            result["distance"] = dist
            result["screen_position"] = screen_pos
    return result

func _process(delta: float) -> void:
    _pulse_time += delta
    queue_redraw()

func _draw() -> void:
    # Deep-blue magical map background.
    draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color("10172d"))
    _draw_arcane_grid()
    _draw_landmasses()
    _draw_routes()
    _draw_destinations()
    _draw_vignette_marks()

func _draw_arcane_grid() -> void:
    var grid_color := Color(0.25, 0.58, 0.78, 0.10)
    var major_color := Color(0.35, 0.72, 0.92, 0.15)
    var shifted := pan_offset * 0.22
    for x in range(-128, 700, 64):
        var px := fposmod(float(x) + shifted.x, 640.0) - 64.0
        draw_line(Vector2(px, 0), Vector2(px, VIEW_SIZE.y), grid_color, 1.0)
    for y in range(-128, 700, 64):
        var py := fposmod(float(y) + shifted.y, 640.0) - 64.0
        draw_line(Vector2(0, py), Vector2(VIEW_SIZE.x, py), grid_color, 1.0)
    for radius in [92.0, 156.0, 220.0, 292.0]:
        draw_arc(CENTER + pan_offset * 0.08, radius, 0.0, TAU, 96, major_color, 1.0)

func _draw_landmasses() -> void:
    # Stylized, procedural land silhouettes. They move with the map pan.
    var base := CENTER + pan_offset
    var land_a := PackedVector2Array([
        base + Vector2(-330,-180), base + Vector2(-210,-235), base + Vector2(-85,-195),
        base + Vector2(-55,-110), base + Vector2(-120,-25), base + Vector2(-235,10),
        base + Vector2(-330,-70)
    ])
    var land_b := PackedVector2Array([
        base + Vector2(55,-285), base + Vector2(170,-250), base + Vector2(260,-170),
        base + Vector2(235,-50), base + Vector2(135,10), base + Vector2(45,-55),
        base + Vector2(5,-155)
    ])
    var land_c := PackedVector2Array([
        base + Vector2(-120,105), base + Vector2(10,70), base + Vector2(145,115),
        base + Vector2(210,220), base + Vector2(120,310), base + Vector2(-10,275),
        base + Vector2(-155,210)
    ])
    draw_colored_polygon(land_a, Color(0.11, 0.25, 0.31, 0.92))
    draw_colored_polygon(land_b, Color(0.13, 0.29, 0.34, 0.92))
    draw_colored_polygon(land_c, Color(0.10, 0.23, 0.30, 0.94))
    for poly in [land_a, land_b, land_c]:
        var outline := poly.duplicate()
        outline.append(poly[0])
        draw_polyline(outline, Color(0.38, 0.75, 0.82, 0.28), 2.0, true)

func _draw_routes() -> void:
    if destinations.size() < 2:
        return
    var route_color := Color(0.48, 0.80, 1.0, 0.32)
    var route_glow := Color(0.38, 0.45, 1.0, 0.10)
    for i in range(destinations.size() - 1):
        var a: Vector2 = CENTER + destinations[i].get("pos", Vector2.ZERO) + pan_offset
        var b: Vector2 = CENTER + destinations[i + 1].get("pos", Vector2.ZERO) + pan_offset
        draw_dashed_line(a, b, route_glow, 5.0, 12.0)
        draw_dashed_line(a, b, route_color, 1.5, 12.0)

func _draw_destinations() -> void:
    for i in range(destinations.size()):
        var data: Dictionary = destinations[i]
        var screen_pos: Vector2 = CENTER + data.get("pos", Vector2.ZERO) + pan_offset
        var is_candidate := i == candidate_index
        var is_selected := i == selected_index
        var pulse := 0.5 + 0.5 * sin(_pulse_time * 4.0 + float(i))
        var outer := Color(0.35, 0.70, 1.0, 0.28)
        var inner := Color(0.45, 0.85, 1.0, 0.95)
        if is_candidate:
            outer = Color(0.76, 0.36, 1.0, 0.45 + candidate_strength * 0.35)
            inner = Color(0.86, 0.58, 1.0, 1.0)
        if is_selected:
            outer = Color(0.97, 0.72, 0.28, 0.62)
            inner = Color(1.0, 0.87, 0.46, 1.0)
        draw_circle(screen_pos, 15.0 + pulse * 3.0, outer)
        draw_circle(screen_pos, 8.0, Color(0.04, 0.08, 0.16, 0.95))
        draw_circle(screen_pos, 4.5, inner)
        draw_arc(screen_pos, 11.0, _pulse_time + i, _pulse_time + i + PI * 1.35, 24, inner, 1.5)

func _draw_vignette_marks() -> void:
    var c := Color(0.45, 0.72, 1.0, 0.12)
    for i in range(16):
        var angle := TAU * float(i) / 16.0
        var r1 := 214.0
        var r2 := 226.0 if i % 2 == 0 else 220.0
        var a := CENTER + Vector2.RIGHT.rotated(angle) * r1
        var b := CENTER + Vector2.RIGHT.rotated(angle) * r2
        draw_line(a, b, c, 1.5)
