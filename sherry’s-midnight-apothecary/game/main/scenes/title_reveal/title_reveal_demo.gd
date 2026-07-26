extends CanvasLayer

const DIM_TARGET_ALPHA := 0.26

@export var input_enabled := true
@export var hint_visible := true
@export var auto_fade_seconds := 0.0

var dim_tween: Tween = null
var fade_tween: Tween = null
var fade_sequence_id := 0
var pending_fade_seconds := 0.0

@onready var overlay: Control = $Overlay
@onready var dim: ColorRect = $Overlay/Dim
@onready var banner: Node = $Overlay/TitleRevealBanner
@onready var key_hint: Label = $Overlay/KeyHint


func _ready() -> void:
	layer = 80
	hide_now()
	key_hint.visible = hint_visible


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_E:
			play_demo()
			var viewport := get_viewport()
			if viewport != null:
				viewport.set_input_as_handled()


func play_demo(fade_after_seconds := -1.0) -> void:
	if dim_tween != null:
		dim_tween.kill()
	if fade_tween != null:
		fade_tween.kill()
	fade_sequence_id += 1

	pending_fade_seconds = auto_fade_seconds if fade_after_seconds < 0.0 else fade_after_seconds
	overlay.visible = true
	banner.modulate = Color.WHITE
	key_hint.visible = hint_visible
	key_hint.modulate = Color(1.0, 1.0, 1.0, 0.38)

	if pending_fade_seconds > 0.0 and banner.has_signal("reveal_finished"):
		var callback := Callable(self, "_on_banner_reveal_finished")
		if banner.is_connected("reveal_finished", callback):
			banner.disconnect("reveal_finished", callback)
		banner.connect("reveal_finished", callback, CONNECT_ONE_SHOT)

	dim_tween = create_tween()
	dim_tween.tween_method(_set_dim_alpha, dim.color.a, DIM_TARGET_ALPHA, 0.18)
	banner.call("play_show")


func hide_now() -> void:
	if dim_tween != null:
		dim_tween.kill()
	if fade_tween != null:
		fade_tween.kill()
	fade_sequence_id += 1
	_set_dim_alpha(0.0)
	banner.modulate = Color.WHITE
	key_hint.modulate = Color(1.0, 1.0, 1.0, 0.38)
	key_hint.visible = hint_visible
	banner.call("hide_now")
	overlay.visible = false


func fade_out() -> void:
	if fade_tween != null:
		fade_tween.kill()
	if dim_tween != null:
		dim_tween.kill()

	fade_tween = create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_method(_set_dim_alpha, dim.color.a, 0.0, 0.48).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade_tween.tween_property(banner, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.48).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade_tween.tween_property(key_hint, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade_tween.finished.connect(_on_fade_finished, CONNECT_ONE_SHOT)


func _set_dim_alpha(alpha: float) -> void:
	var color := dim.color
	color.a = clampf(alpha, 0.0, 1.0)
	dim.color = color


func _on_banner_reveal_finished() -> void:
	var sequence_id := fade_sequence_id
	var seconds := pending_fade_seconds
	if seconds <= 0.0:
		return
	await get_tree().create_timer(seconds).timeout
	if sequence_id != fade_sequence_id:
		return
	fade_out()


func _on_fade_finished() -> void:
	banner.call("hide_now")
	banner.modulate = Color.WHITE
	key_hint.modulate = Color(1.0, 1.0, 1.0, 0.38)
	overlay.visible = false
