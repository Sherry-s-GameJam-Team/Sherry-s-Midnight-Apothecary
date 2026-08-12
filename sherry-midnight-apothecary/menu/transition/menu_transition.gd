class_name MenuTransitionDirector
extends Node

signal fully_covered
signal reveal_finished

@export var shadow_path: NodePath
@export var roof_path: NodePath

var _shadow: ColorRect
var _roof: ColorRect
var _covered := false
var _revealing := false


func _ready() -> void:
	_shadow = get_node(shadow_path) as ColorRect
	_roof = get_node(roof_path) as ColorRect
	_resize_roof()
	get_viewport().size_changed.connect(_resize_roof)


func play_shadow() -> void:
	var material := _shadow.material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("progress", 0.0)
	var tween := create_tween()
	tween.tween_method(func(value: float) -> void: material.set_shader_parameter("progress", value), 0.0, 0.7, 4.2)


func cover_with_roof() -> void:
	if _covered:
		return
	var viewport_height := get_viewport().get_visible_rect().size.y
	_roof.position.y = viewport_height
	var tween := create_tween()
	tween.tween_property(_roof, "position:y", 0.0, 0.34).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	await tween.finished
	_covered = true
	fully_covered.emit()


func reveal_runtime() -> void:
	if not _covered:
		return
	_revealing = true
	var viewport_height := get_viewport().get_visible_rect().size.y
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_roof, "position:y", -viewport_height, 0.52).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	var material := _shadow.material as ShaderMaterial
	if material != null:
		tween.tween_method(func(value: float) -> void: material.set_shader_parameter("progress", value), 0.7, 0.0, 0.48)
	await tween.finished
	_revealing = false
	_covered = false
	reveal_finished.emit()


func is_revealing() -> bool:
	return _revealing


func _resize_roof() -> void:
	if _roof == null:
		return
	_roof.size = get_viewport().get_visible_rect().size
	if not _covered:
		_roof.position.y = _roof.size.y
