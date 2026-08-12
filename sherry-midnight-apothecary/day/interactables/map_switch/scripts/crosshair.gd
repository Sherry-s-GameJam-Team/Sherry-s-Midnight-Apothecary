extends Node2D
class_name MapCrosshair

var active := false:
    set(value):
        active = value
        visible = value
        queue_redraw()

var _time := 0.0

func _ready() -> void:
    visible = active
    set_process(true)

func _process(delta: float) -> void:
    _time += delta
    if active:
        queue_redraw()

func _draw() -> void:
    if not active:
        return
    var pulse := 0.5 + 0.5 * sin(_time * 3.5)
    var cyan := Color(0.43, 0.87, 1.0, 0.82)
    var violet := Color(0.75, 0.43, 1.0, 0.42 + pulse * 0.22)
    draw_circle(Vector2.ZERO, 6.5, Color(0.03, 0.05, 0.10, 0.82))
    draw_arc(Vector2.ZERO, 18.0 + pulse * 2.0, 0.0, TAU, 48, violet, 2.0)
    draw_arc(Vector2.ZERO, 7.5, 0.0, TAU, 32, cyan, 1.6)
    draw_line(Vector2(-31, 0), Vector2(-11, 0), cyan, 1.4)
    draw_line(Vector2(11, 0), Vector2(31, 0), cyan, 1.4)
    draw_line(Vector2(0, -31), Vector2(0, -11), cyan, 1.4)
    draw_line(Vector2(0, 11), Vector2(0, 31), cyan, 1.4)
