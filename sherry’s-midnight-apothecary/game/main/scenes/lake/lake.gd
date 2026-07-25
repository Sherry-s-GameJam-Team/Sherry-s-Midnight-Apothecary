extends Node2D

@onready var camera_controller: TownCameraController = $TownCameraController
@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var reveal_target: Node2D = $RightLakeRevealTrigger/CollisionShape2D
@onready var player_sprite_pivot: Node2D = $Player/SpritePivot
@onready var player_sprite: AnimatedSprite2D = $Player/SpritePivot/WitchSprite

const NORMAL_ZOOM := 1.35
const LAKE_REVEAL_ZOOM := 1.0
const NORMAL_RIGHT_BOUND := 1830.0
const LAKE_REVEAL_RIGHT_BOUND := 2999.0
const LAKE_REVEAL_CAMERA_OFFSET := Vector2(360.0, 0.0)
const LAKE_REVEAL_START_X := 1450.0
const LAKE_REVEAL_END_X := 1830.0

var saved_camera_state: Dictionary = {}
var reveal_start_position := Vector2.ZERO
var reveal_target_position := Vector2.ZERO
var reveal_start_zoom := Vector2.ONE


func _ready() -> void:
	# Lake uses the same outdoor camera state machine as TownMorning.
	camera_controller.enter_outdoor_mode(true)
	process_priority = 100
	# Keep the player render transform in the same frame as the camera reveal.
	player.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	player_sprite_pivot.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	player_sprite.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	player.reset_physics_interpolation()
	player_sprite_pivot.reset_physics_interpolation()
	player_sprite.reset_physics_interpolation()


func _physics_process(_delta: float) -> void:
	if saved_camera_state.is_empty():
		if player.global_position.x >= LAKE_REVEAL_START_X:
			_enter_lake_reveal()
		return

	var reveal_progress := clampf(
		inverse_lerp(LAKE_REVEAL_START_X, LAKE_REVEAL_END_X, player.global_position.x),
		0.0,
		1.0,
	)
	# Smoothstep keeps the path left-to-right linear while easing its ends.
	var smooth_progress := reveal_progress * reveal_progress * (3.0 - 2.0 * reveal_progress)
	camera.global_position = reveal_start_position.lerp(reveal_target_position, smooth_progress)
	camera.zoom = reveal_start_zoom.lerp(Vector2.ONE * LAKE_REVEAL_ZOOM, smooth_progress)
	camera.limit_left = 0
	camera.limit_right = ceili(LAKE_REVEAL_RIGHT_BOUND)
	camera.limit_top = -1000
	camera.limit_bottom = 1200

	if player.global_position.x < LAKE_REVEAL_START_X:
		_exit_lake_reveal()


func _enter_lake_reveal() -> void:
	if not saved_camera_state.is_empty():
		return

	saved_camera_state = {
		"position": camera.global_position,
		"zoom": camera.zoom,
		"limit_left": camera.limit_left,
		"limit_right": camera.limit_right,
		"limit_top": camera.limit_top,
		"limit_bottom": camera.limit_bottom,
		"position_smoothing_enabled": camera.position_smoothing_enabled,
		"position_smoothing_speed": camera.position_smoothing_speed,
		"outdoor_right_bound": camera_controller.outdoor_right_bound,
	}

	# Start from the editor-positioned reveal target, then bias the shot toward
	# the lake edge so the port does not remain centered in the reveal view.
	camera_controller.outdoor_right_bound = LAKE_REVEAL_RIGHT_BOUND
	reveal_start_position = camera.global_position
	reveal_start_zoom = camera.zoom
	reveal_target_position = reveal_target.global_position + LAKE_REVEAL_CAMERA_OFFSET
	# Freeze the Town controller while the player drives this linear reveal.
	camera_controller.enter_title_mode(reveal_start_position)
	# The reveal is authored in physics space; interpolation against the old
	# camera transform causes a visible afterimage across the trigger range.
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.reset_physics_interpolation()


func _exit_lake_reveal() -> void:
	if saved_camera_state.is_empty():
		return

	camera_controller.outdoor_right_bound = NORMAL_RIGHT_BOUND
	# Return control to the same outdoor camera state machine used by Town.
	camera_controller.enter_outdoor_mode(false)
	camera.position_smoothing_enabled = saved_camera_state["position_smoothing_enabled"]
	camera.position_smoothing_speed = saved_camera_state["position_smoothing_speed"]
	saved_camera_state.clear()
