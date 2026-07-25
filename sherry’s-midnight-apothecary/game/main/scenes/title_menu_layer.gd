extends CanvasLayer

signal start_requested
signal quit_requested

const FADE_DURATION := 0.32
const TITLE_FLOAT_AMPLITUDE := 4.2
const TITLE_FLOAT_SPEED := 1.55
const TITLE_FLOAT_PHASE_STEP := 0.72

var is_closing := false
var fade_tween: Tween = null
var title_float_time := 0.0
var title_glyph_base_y := PackedFloat32Array()

@onready var overlay: Control = $Overlay
@onready var title_glyphs: Array[TextureRect] = [
	$Overlay/TitleGlyph01,
	$Overlay/TitleGlyph02,
	$Overlay/TitleGlyph03,
	$Overlay/TitleGlyph04,
	$Overlay/TitleGlyph05,
	$Overlay/TitleGlyph06,
	$Overlay/TitleGlyph07,
	$Overlay/TitleGlyph08,
]
@onready var start_button: Button = $Overlay/Menu/StartButton
@onready var quit_button: Button = $Overlay/Menu/QuitButton


func _ready() -> void:
	layer = 90
	overlay.modulate = Color.WHITE
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	start_button.call_deferred("grab_focus")
	for glyph in title_glyphs:
		title_glyph_base_y.append(glyph.position.y)


func _process(delta: float) -> void:
	if is_closing or title_glyph_base_y.size() != title_glyphs.size():
		return

	title_float_time += delta
	for index in title_glyphs.size():
		var glyph := title_glyphs[index]
		var amplitude := TITLE_FLOAT_AMPLITUDE + float(index % 3) * 0.65
		var speed := TITLE_FLOAT_SPEED + float(index % 4) * 0.07
		var phase := float(index) * TITLE_FLOAT_PHASE_STEP
		glyph.position.y = title_glyph_base_y[index] + sin(title_float_time * speed + phase) * amplitude


func _unhandled_input(event: InputEvent) -> void:
	if is_closing or not visible:
		return

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_SPACE:
				_on_start_pressed()
				_mark_input_handled()
			elif key_event.keycode == KEY_ESCAPE:
				_on_quit_pressed()
				_mark_input_handled()


func fade_out() -> void:
	is_closing = true
	start_button.disabled = true
	quit_button.disabled = true
	if fade_tween != null:
		fade_tween.kill()

	fade_tween = create_tween()
	fade_tween.set_trans(Tween.TRANS_SINE)
	fade_tween.set_ease(Tween.EASE_IN_OUT)
	fade_tween.tween_property(overlay, "modulate", Color(1.0, 1.0, 1.0, 0.0), FADE_DURATION)
	fade_tween.finished.connect(_on_fade_finished, CONNECT_ONE_SHOT)


func _on_start_pressed() -> void:
	if is_closing:
		return
	start_requested.emit()


func _on_quit_pressed() -> void:
	if is_closing:
		return
	quit_requested.emit()


func _mark_input_handled() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _on_fade_finished() -> void:
	visible = false
	fade_tween = null
