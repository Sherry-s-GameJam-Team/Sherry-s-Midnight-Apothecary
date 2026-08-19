class_name RunnerTrackGenerator
extends Node2D

## Procedural and phased obstacle track generator for the 2-minute parkour corridor.
## Spawns lower-track beds/stretchers (Space to jump) and upper-track vines/lamps (W to jump).
## Dynamically creates and recycles corridor segments ahead of the runner.

const BED_TEX := preload("res://day/levels/Vespervale/src/bed.png")
const STRETCHER_TEX := preload("res://day/levels/Vespervale/src/stretcher.png")
const LIGHT_TEX := preload("res://day/levels/Vespervale/src/light.png")
const LIGHT_BROKEN_TEX := preload("res://day/levels/Vespervale/src/light_broken.png")
const WALL_TEX := preload("res://day/levels/Vespervale/inside church.png")

@export var chunk_length: float = 2400.0
@export var total_track_distance: float = 36000.0 # 300px/s * 120s
@export var lower_track_y: float = 580.0
@export var upper_track_y: float = 320.0

var _spawned_distance: float = 0.0
var _active_chunks: Array[Node2D] = []
var _obstacle_index: int = 0

@onready var runner_controller: RunnerController = get_node_or_null("../RunnerController")


func _ready() -> void:
	# Initial spawn of first 3 chunks (7200px)
	for i in range(3):
		_spawn_next_chunk()


func _physics_process(_delta: float) -> void:
	if runner_controller == null:
		return

	var current_runner_x := 0.0
	if runner_controller.sherry != null:
		current_runner_x = runner_controller.sherry.position.x

	# Spawn ahead if runner gets close to end of generated track
	if current_runner_x + 4000.0 > _spawned_distance and _spawned_distance < total_track_distance + 2000.0:
		_spawn_next_chunk()

	# Recycle chunks that are far behind runner
	_recycle_old_chunks(current_runner_x)


func _spawn_next_chunk() -> void:
	var start_x := _spawned_distance
	var end_x := start_x + chunk_length
	_spawned_distance = end_x

	var chunk := Node2D.new()
	chunk.name = "TrackChunk_%d" % _active_chunks.size()
	chunk.position = Vector2(start_x, 0)
	add_child(chunk)
	_active_chunks.append(chunk)

	# 1. Background wall repeat
	var wall := Sprite2D.new()
	wall.texture = WALL_TEX
	wall.centered = false
	wall.position = Vector2(0, -50)
	wall.scale = Vector2(1.2, 1.07)
	wall.z_index = -25
	chunk.add_child(wall)

	# 2. Upper Platform line
	var plat_body := StaticBody2D.new()
	plat_body.collision_layer = 3
	plat_body.collision_mask = 0
	var plat_col := CollisionShape2D.new()
	var plat_shape := RectangleShape2D.new()
	plat_shape.size = Vector2(chunk_length, 24)
	plat_col.shape = plat_shape
	plat_col.position = Vector2(chunk_length * 0.5, upper_track_y + 20.0)
	plat_body.add_child(plat_col)
	chunk.add_child(plat_body)

	# 3. Generate staged obstacles for this segment
	if start_x >= 800.0 and start_x < total_track_distance:
		_populate_chunk_obstacles(chunk, start_x)


func _populate_chunk_obstacles(chunk: Node2D, global_start_x: float) -> void:
	var progress := clampf(global_start_x / total_track_distance, 0.0, 1.0)
	var obstacle_count := 3
	if progress > 0.5:
		obstacle_count = 4
	if progress > 0.8:
		obstacle_count = 5

	var step := chunk_length / float(obstacle_count + 1)
	for i in range(1, obstacle_count + 1):
		var local_x := float(i) * step + randf_range(-60.0, 60.0)
		_obstacle_index += 1

		# Pattern determination by phase
		var pattern := (_obstacle_index % 3)
		if progress > 0.6 and (_obstacle_index % 4 == 0):
			# Dual obstacle requiring simultaneous W + Space jump!
			_create_lower_obstacle(chunk, local_x)
			_create_upper_obstacle(chunk, local_x + 30.0)
		elif pattern == 0 or pattern == 1:
			# Sherry lower obstacle (Space jump)
			_create_lower_obstacle(chunk, local_x)
		else:
			# Luca upper obstacle (W jump)
			_create_upper_obstacle(chunk, local_x)


func _create_lower_obstacle(chunk: Node2D, local_x: float) -> void:
	var obs := Area2D.new()
	obs.name = "LowerObs_%d" % _obstacle_index
	obs.set_script(RunnerObstacle)
	obs.set("target_track", RunnerObstacle.TargetTrack.LOWER_SHERRY)
	obs.position = Vector2(local_x, lower_track_y - 15.0)

	var is_stretcher := randf() > 0.5
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = STRETCHER_TEX if is_stretcher else BED_TEX
	sprite.scale = Vector2(0.4, 0.4)
	obs.add_child(sprite)

	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(70, 45)
	col.shape = shape
	obs.add_child(col)

	chunk.add_child(obs)


func _create_upper_obstacle(chunk: Node2D, local_x: float) -> void:
	var obs := Area2D.new()
	obs.name = "UpperObs_%d" % _obstacle_index
	obs.set_script(RunnerObstacle)
	obs.set("target_track", RunnerObstacle.TargetTrack.UPPER_LUCA)
	obs.position = Vector2(local_x, upper_track_y - 20.0)

	var is_broken := randf() > 0.5
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = LIGHT_BROKEN_TEX if is_broken else LIGHT_TEX
	sprite.scale = Vector2(0.4, 0.4)
	obs.add_child(sprite)

	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(50, 50)
	col.shape = shape
	obs.add_child(col)

	chunk.add_child(obs)


func _recycle_old_chunks(runner_x: float) -> void:
	while _active_chunks.size() > 4:
		var oldest := _active_chunks[0]
		if oldest.position.x + chunk_length + 2000.0 < runner_x:
			_active_chunks.remove_at(0)
			oldest.queue_free()
		else:
			break
