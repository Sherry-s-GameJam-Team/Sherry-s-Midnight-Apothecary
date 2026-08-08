extends Node2D
class_name DialMagicOverlay

var intensity := 0.0:
    set(value):
        intensity = clampf(value, 0.0, 1.0)
        visible = intensity > 0.001
        queue_redraw()

var radius := 214.0
var _time := 0.0

func _ready() -> void:
    set_process(true)
    visible = false

func _process(delta: float) -> void:
    _time += delta
    if intensity > 0.001:
        queue_redraw()

func _draw() -> void:
    if intensity <= 0.001:
        return
    var fade := intensity
    var cyan := Color(0.32, 0.80, 1.0, 0.16 * fade)
    var violet := Color(0.76, 0.35, 1.0, 0.22 * fade)
    draw_arc(Vector2.ZERO, radius + sin(_time * 5.0) * 4.0, _time, _time + TAU * 0.72, 96, violet, 3.0)
    draw_arc(Vector2.ZERO, radius - 12.0, -_time * 1.35, -_time * 1.35 + TAU * 0.55, 96, cyan, 2.0)
    for i in range(14):
        var angle := TAU * float(i) / 14.0 + _time * (0.35 if i % 2 == 0 else -0.23)
        var jitter := sin(_time * 4.0 + float(i) * 1.7) * 8.0
        var p := Vector2.RIGHT.rotated(angle) * (radius - 18.0 + jitter)
        var spark_size := 2.2 + 2.0 * (0.5 + 0.5 * sin(_time * 7.0 + i))
        draw_circle(p, spark_size, Color(0.66, 0.48, 1.0, 0.45 * fade))
