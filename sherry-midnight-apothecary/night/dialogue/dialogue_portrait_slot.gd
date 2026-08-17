class_name DialoguePortraitSlot
extends Control

const DialoguePortraitDatabase := preload("res://night/dialogue/portrait_database.gd")

## Single character portrait slot for Dialogue UI.
## Handles cross-fading expression changes, focus dimming, and entrance/exit tweens.

enum SlotId { LEFT, CENTER, RIGHT }

@export var slot_id: SlotId = SlotId.CENTER
@export var enter_duration: float = 0.35
@export var exit_duration: float = 0.25
@export var crossfade_duration: float = 0.2
@export var unfocused_modulate: Color = Color(0.62, 0.62, 0.66, 1.0)
@export var focused_modulate: Color = Color(1.0, 1.0, 1.0, 1.0)

var current_character: String = ""
var current_expression: String = ""
var is_active: bool = false

var _main_rect: TextureRect
var _crossfade_rect: TextureRect
var _anim_tween: Tween
var _focus_tween: Tween
var _crossfade_tween: Tween
var _base_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_children()
	modulate.a = 0.0
	visible = false


func _setup_children() -> void:
	if _main_rect == null:
		_main_rect = TextureRect.new()
		_main_rect.name = "MainRect"
		_main_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_main_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_main_rect.anchor_right = 1.0
		_main_rect.anchor_bottom = 1.0
		_main_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_main_rect)

	if _crossfade_rect == null:
		_crossfade_rect = TextureRect.new()
		_crossfade_rect.name = "CrossfadeRect"
		_crossfade_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_crossfade_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_crossfade_rect.anchor_right = 1.0
		_crossfade_rect.anchor_bottom = 1.0
		_crossfade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_crossfade_rect.modulate.a = 0.0
		add_child(_crossfade_rect)


## Shows a portrait texture with specified expression and animation.
func show_portrait(
	character_name: String,
	expression: String = "default",
	animation: String = "slide_in",
	custom_texture: Texture2D = null
) -> void:
	_setup_children()
	var texture := custom_texture if custom_texture != null else DialoguePortraitDatabase.get_portrait_texture(character_name, expression)
	if texture == null:
		push_warning("DialoguePortraitSlot: Could not resolve texture for '%s' (expression: '%s')" % [character_name, expression])
		return

	var is_same_character: bool = (is_active and current_character == character_name)
	var is_same_expression: bool = (is_same_character and current_expression == expression)

	current_character = character_name
	current_expression = expression
	visible = true

	if is_active and is_same_character:
		if not is_same_expression:
			_crossfade_to(texture)
		_play_reaction_animation(animation)
	else:
		is_active = true
		_main_rect.texture = texture
		_main_rect.modulate.a = 1.0
		_crossfade_rect.modulate.a = 0.0
		_play_enter_animation(animation)


## Hides the portrait with an exit animation.
func hide_portrait(animation: String = "slide_out") -> void:
	if not is_active:
		return
	is_active = false
	current_character = ""
	current_expression = ""
	_play_exit_animation(animation)


## Instantly resets the slot to empty and hidden.
func clear_instant() -> void:
	_kill_tweens()
	is_active = false
	current_character = ""
	current_expression = ""
	modulate.a = 0.0
	position = _base_offset
	visible = false
	if _main_rect != null:
		_main_rect.texture = null
		_main_rect.modulate.a = 1.0
	if _crossfade_rect != null:
		_crossfade_rect.texture = null
		_crossfade_rect.modulate.a = 0.0


## Sets whether this portrait is the currently speaking character.
func set_focused(focused: bool, animated: bool = true) -> void:
	if not is_active:
		return
	var target_modulate := focused_modulate if focused else unfocused_modulate
	var target_scale := Vector2.ONE if focused else Vector2(0.97, 0.97)

	if _focus_tween and _focus_tween.is_valid():
		_focus_tween.kill()

	if animated:
		_focus_tween = create_tween().set_parallel(true)
		_focus_tween.tween_property(self, "modulate:r", target_modulate.r, 0.22)
		_focus_tween.tween_property(self, "modulate:g", target_modulate.g, 0.22)
		_focus_tween.tween_property(self, "modulate:b", target_modulate.b, 0.22)
		_focus_tween.tween_property(self, "scale", target_scale, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		modulate.r = target_modulate.r
		modulate.g = target_modulate.g
		modulate.b = target_modulate.b
		scale = target_scale


func _crossfade_to(new_texture: Texture2D) -> void:
	if _crossfade_tween and _crossfade_tween.is_valid():
		_crossfade_tween.kill()

	_crossfade_rect.texture = new_texture
	_crossfade_rect.modulate.a = 0.0
	_crossfade_tween = create_tween()
	_crossfade_tween.tween_property(_crossfade_rect, "modulate:a", 1.0, crossfade_duration)
	await _crossfade_tween.finished
	_main_rect.texture = new_texture
	_main_rect.modulate.a = 1.0
	_crossfade_rect.modulate.a = 0.0
	_crossfade_rect.texture = null


func _play_enter_animation(anim_name: String) -> void:
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()

	var travel_offset := _get_slide_offset()
	var start_pos := _base_offset + travel_offset
	var end_pos := _base_offset

	match anim_name:
		"fade_in", "fade":
			position = end_pos
			modulate.a = 0.0
			_anim_tween = create_tween()
			_anim_tween.tween_property(self, "modulate:a", 1.0, enter_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		"pop", "bounce":
			position = end_pos
			modulate.a = 0.0
			scale = Vector2(0.85, 0.85)
			_anim_tween = create_tween().set_parallel(true)
			_anim_tween.tween_property(self, "modulate:a", 1.0, enter_duration * 0.7)
			_anim_tween.tween_property(self, "scale", Vector2(1.05, 1.05), enter_duration * 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_anim_tween.chain().tween_property(self, "scale", Vector2.ONE, enter_duration * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

		_: # Default "slide_in" or "slide"
			position = start_pos
			modulate.a = 0.0
			_anim_tween = create_tween().set_parallel(true)
			_anim_tween.tween_property(self, "position", end_pos, enter_duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
			_anim_tween.tween_property(self, "modulate:a", 1.0, enter_duration * 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _play_exit_animation(anim_name: String) -> void:
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()

	var exit_pos := _base_offset + _get_slide_offset() * 0.65

	match anim_name:
		"fade_out", "fade":
			_anim_tween = create_tween()
			_anim_tween.tween_property(self, "modulate:a", 0.0, exit_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			await _anim_tween.finished
			visible = false

		_: # Default "slide_out" or "slide"
			_anim_tween = create_tween().set_parallel(true)
			_anim_tween.tween_property(self, "position", exit_pos, exit_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			_anim_tween.tween_property(self, "modulate:a", 0.0, exit_duration * 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			await _anim_tween.finished
			visible = false


func _play_reaction_animation(anim_name: String) -> void:
	match anim_name:
		"shake":
			if _anim_tween and _anim_tween.is_valid():
				_anim_tween.kill()
			_anim_tween = create_tween()
			var ox := _base_offset.x
			_anim_tween.tween_property(self, "position:x", ox - 10.0, 0.06)
			_anim_tween.tween_property(self, "position:x", ox + 10.0, 0.06)
			_anim_tween.tween_property(self, "position:x", ox - 6.0, 0.06)
			_anim_tween.tween_property(self, "position:x", ox + 6.0, 0.06)
			_anim_tween.tween_property(self, "position:x", ox, 0.06)

		"bounce", "pop":
			if _anim_tween and _anim_tween.is_valid():
				_anim_tween.kill()
			_anim_tween = create_tween()
			_anim_tween.tween_property(self, "scale", Vector2(1.06, 1.06), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_anim_tween.tween_property(self, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

		"nod":
			if _anim_tween and _anim_tween.is_valid():
				_anim_tween.kill()
			var oy := _base_offset.y
			_anim_tween = create_tween()
			_anim_tween.tween_property(self, "position:y", oy + 12.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_anim_tween.tween_property(self, "position:y", oy, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _get_slide_offset() -> Vector2:
	match slot_id:
		SlotId.LEFT:
			return Vector2(-45.0, 15.0)
		SlotId.RIGHT:
			return Vector2(45.0, 15.0)
		_:
			return Vector2(0.0, 30.0)


func _kill_tweens() -> void:
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	if _focus_tween and _focus_tween.is_valid():
		_focus_tween.kill()
	if _crossfade_tween and _crossfade_tween.is_valid():
		_crossfade_tween.kill()
