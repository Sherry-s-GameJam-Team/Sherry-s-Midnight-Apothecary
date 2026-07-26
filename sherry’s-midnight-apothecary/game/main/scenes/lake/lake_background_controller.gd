extends Node2D

## Owns lake background parallax only. It never changes vertical placement,
## scale, Camera2D state, or reads Player state.

@export_group("Node References")
@export_node_path("Camera2D") var camera_path: NodePath
@export_node_path("Node2D") var far_background_path: NodePath
@export_node_path("Node2D") var cloud_big_path: NodePath
@export_node_path("Node2D") var cloud_small_path: NodePath

@export_group("Parallax")
@export_range(0.0, 1.0, 0.01) var far_parallax := 0.35
@export_range(0.0, 1.0, 0.01) var cloud_big_parallax := 0.20
@export_range(0.0, 1.0, 0.01) var cloud_small_parallax := 0.28

@export_group("Cloud Motion")
@export var cloud_big_speed := 13.0
@export var cloud_small_speed := 5.0
@export var cloud_big_texture_width := 1615.0
@export var cloud_small_texture_width := 1672.0

@export_group("Debug")
@export var debug_enabled := false

@onready var camera := get_node_or_null(camera_path) as Camera2D
@onready var far_background := get_node_or_null(far_background_path) as Node2D
@onready var cloud_big := get_node_or_null(cloud_big_path) as Node2D
@onready var cloud_small := get_node_or_null(cloud_small_path) as Node2D

var _reference_camera_x := 0.0
var _far_reference := Vector2.ZERO
var _cloud_big_reference := Vector2.ZERO
var _cloud_small_reference := Vector2.ZERO
var _cloud_big_scroll := 0.0
var _cloud_small_scroll := 0.0


func _ready() -> void:
	if camera == null or far_background == null or cloud_big == null or cloud_small == null:
		push_error("LakeBackgroundController requires camera, far background, and both cloud layers.")
		set_process(false)
		return

	_reference_camera_x = camera.global_position.x
	_far_reference = far_background.position
	_cloud_big_reference = cloud_big.position
	_cloud_small_reference = cloud_small.position


func _process(delta: float) -> void:
	_cloud_big_scroll = wrapf(
		_cloud_big_scroll - cloud_big_speed * delta,
		-cloud_big_texture_width,
		0.0,
	)
	_cloud_small_scroll = wrapf(
		_cloud_small_scroll - cloud_small_speed * delta,
		-cloud_small_texture_width,
		0.0,
	)

	var camera_offset_x := camera.global_position.x - _reference_camera_x
	far_background.position.x = _far_reference.x + camera_offset_x * (1.0 - far_parallax)
	cloud_big.position.x = _cloud_big_reference.x \
		+ camera_offset_x * (1.0 - cloud_big_parallax) + _cloud_big_scroll
	cloud_small.position.x = _cloud_small_reference.x \
		+ camera_offset_x * (1.0 - cloud_small_parallax) + _cloud_small_scroll

	# Preserve all editor-authored vertical positions and scales.
	far_background.position.y = _far_reference.y
	cloud_big.position.y = _cloud_big_reference.y
	cloud_small.position.y = _cloud_small_reference.y

	if debug_enabled:
		queue_redraw()


func get_debug_state() -> Dictionary:
	return {
		"far_offset_x": far_background.position.x - _far_reference.x,
		"cloud_big_offset_x": cloud_big.position.x - _cloud_big_reference.x,
		"cloud_small_offset_x": cloud_small.position.x - _cloud_small_reference.x,
		"cloud_big_scroll": _cloud_big_scroll,
		"cloud_small_scroll": _cloud_small_scroll,
	}
