class_name DistillationFillController
extends Node2D

## Per-device liquid fill driver. Attach it to a DistillationDevice node.
signal fill_animation_finished(target_progress: float)

@export var liquid_layer: CanvasItem
@export_node_path("CanvasItem") var liquid_layer_path: NodePath
@export var flow_order_texture: Texture2D

var _fill_progress := 0.0
var _shader_material: ShaderMaterial
var _fill_tween: Tween

var fill_progress: float:
	get:
		return _fill_progress
	set(value):
		set_fill_progress(value)


func _ready() -> void:
	if liquid_layer == null and not liquid_layer_path.is_empty():
		liquid_layer = get_node_or_null(liquid_layer_path) as CanvasItem
	if liquid_layer == null:
		push_error("DistillationFillController: assign a Sprite2D or TextureRect to liquid_layer.")
		return
	if flow_order_texture == null:
		push_error("DistillationFillController: assign flow_order.png to flow_order_texture.")
		return
	if not (liquid_layer is Sprite2D or liquid_layer is TextureRect):
		push_error("DistillationFillController: liquid_layer must be a Sprite2D or TextureRect.")
		return
	if not liquid_layer.material is ShaderMaterial:
		push_error("DistillationFillController: liquid_layer requires a ShaderMaterial.")
		return

	_shader_material = (liquid_layer.material as ShaderMaterial).duplicate(true) as ShaderMaterial
	liquid_layer.material = _shader_material
	_shader_material.set_shader_parameter(&"flow_order_texture", flow_order_texture)
	set_fill_progress(_fill_progress)


func set_fill_progress(value: float) -> void:
	_fill_progress = clampf(value, 0.0, 1.0)
	if _shader_material != null:
		_shader_material.set_shader_parameter(&"fill_progress", _fill_progress)


func animate_to(target_progress: float, duration: float) -> void:
	stop_animation()
	var target := clampf(target_progress, 0.0, 1.0)
	if is_zero_approx(duration):
		set_fill_progress(target)
		fill_animation_finished.emit(target)
		return
	_fill_tween = create_tween()
	_fill_tween.set_trans(Tween.TRANS_SINE)
	_fill_tween.set_ease(Tween.EASE_IN_OUT)
	_fill_tween.tween_method(set_fill_progress, _fill_progress, target, maxf(duration, 0.0))
	_fill_tween.finished.connect(_on_fill_tween_finished.bind(target))


func play_fill(duration: float) -> void:
	animate_to(1.0, duration)


func play_drain(duration: float) -> void:
	animate_to(0.0, duration)


func stop_animation() -> void:
	if _fill_tween != null and _fill_tween.is_valid():
		_fill_tween.kill()
	_fill_tween = null


func _on_fill_tween_finished(target_progress: float) -> void:
	_fill_tween = null
	fill_animation_finished.emit(target_progress)


func set_liquid_color(color: Color) -> void:
	if _shader_material == null:
		push_error("DistillationFillController: ShaderMaterial is unavailable; configure the node before setting color.")
		return
	_shader_material.set_shader_parameter(&"liquid_color", color)
	var brighter := color.lightened(0.32)
	brighter.a = minf(color.a + 0.12, 1.0)
	_shader_material.set_shader_parameter(&"front_color", brighter)


## Debug/editor helper for visually checking the five required fill thresholds.
func debug_set_preview_step(step: int) -> void:
	if not (Engine.is_editor_hint() or OS.is_debug_build()):
		push_warning("DistillationFillController: debug fill previews are unavailable in release builds.")
		return
	var preview_steps := PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	if step < 0 or step >= preview_steps.size():
		push_error("DistillationFillController: debug preview step must be between 0 and 4.")
		return
	stop_animation()
	set_fill_progress(preview_steps[step])
