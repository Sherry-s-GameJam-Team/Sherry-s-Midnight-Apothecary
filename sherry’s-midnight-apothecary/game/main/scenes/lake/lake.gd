extends Node2D

## Coordinates the lake-reveal trigger. Camera transforms remain entirely in
## TownCameraController; this scene only turns player position into progress.

@export_group("Lake Reveal")
@export var reveal_start_x := 1450.0
@export var reveal_end_x := 1830.0
@export var reveal_target_offset_x := 360.0
@export var reveal_zoom := 1.0
@export var normal_zoom := 1.35
@export var normal_right_limit := 1830.0
@export var reveal_right_limit := 2999.0
@export var normal_camera_offset_y := 392.0
@export var lake_reveal_camera_offset_y := 392.0

@export_group("Node References")
@export_node_path("CharacterBody2D") var player_path: NodePath = NodePath("Player")
@export_node_path("TownCameraController") var camera_controller_path: NodePath = NodePath("TownCameraController")
@export_node_path("Node2D") var reveal_trigger_path: NodePath = NodePath("RightLakeRevealTrigger/CollisionShape2D")

@export_group("Debug")
@export var camera_debug_enabled := false

@onready var player := get_node(player_path) as CharacterBody2D
@onready var camera_controller := get_node(camera_controller_path) as TownCameraController
@onready var reveal_trigger := get_node(reveal_trigger_path) as Node2D

var reveal_progress := 0.0


func _ready() -> void:
	if player == null or camera_controller == null or reveal_trigger == null:
		push_error("Lake requires player, TownCameraController, and reveal trigger references.")
		set_physics_process(false)
		return

	camera_controller.configure_lake_reveal(
		reveal_trigger.global_position.x + reveal_target_offset_x,
		normal_zoom,
		reveal_zoom,
		normal_right_limit,
		reveal_right_limit,
		normal_camera_offset_y,
		lake_reveal_camera_offset_y,
	)
	camera_controller.enter_outdoor_mode(true)


func _physics_process(_delta: float) -> void:
	var next_progress := 0.0
	if player.global_position.x >= reveal_start_x:
		next_progress = clampf(
			inverse_lerp(reveal_start_x, reveal_end_x, player.global_position.x),
			0.0,
			1.0,
		)

	reveal_progress = next_progress
	camera_controller.set_lake_reveal_progress(reveal_progress)
	if reveal_progress <= 0.0 and camera_controller.is_lake_reveal_active():
		camera_controller.exit_lake_reveal()


func _process(_delta: float) -> void:
	if not camera_debug_enabled or player == null or camera_controller == null:
		return
	var lake_camera := camera_controller.get_camera()
	if lake_camera != null:
		print(
			"Lake reveal progress=", snappedf(reveal_progress, 0.001),
			" player_x=", snappedf(player.global_position.x, 0.1),
			" camera=", lake_camera.global_position,
			" zoom=", lake_camera.zoom.x,
			" right_limit=", lake_camera.limit_right,
		)
