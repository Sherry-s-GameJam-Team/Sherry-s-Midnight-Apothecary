class_name EndlessCorridorManager
extends Node2D

## Endless Loop Corridor Manager for Vespervale Inner.
## Causes characters to seamlessly warp back to the corridor entrance when moving right,
## creating an infinite looping space until the required signal is activated.

signal loop_triggered(body: Node2D, total_loops: int)
signal signal_activated
signal loop_unlocked

@export var is_loop_unlocked: bool = true
@export var loop_trigger_x: float = 4600.0
@export var loop_return_x: float = 400.0
@export var trigger_hint_text: String = "回廊空间发生了折叠……似乎在无尽循环。"
@export var right_barrier_path: NodePath = NodePath("../WorldBounds/RightBarrier")

var total_loops: int = 0
var _is_transitioning: bool = false

@onready var trigger_area: Area2D = get_node_or_null("LoopTriggerArea")
@onready var exit_blocker: StaticBody2D = get_node_or_null("ExitBlocker")
@onready var exit_fog: CanvasItem = get_node_or_null("LoopFog")


func _ready() -> void:
	_align_with_right_barrier()
	if trigger_area != null:
		trigger_area.body_entered.connect(_on_trigger_body_entered)
	_update_exit_state()


func _align_with_right_barrier() -> void:
	var root := get_tree().current_scene
	var right_barrier: Node2D = get_node_or_null(right_barrier_path) as Node2D
	if right_barrier == null and root != null:
		right_barrier = root.find_child("RightBarrier", true, false) as Node2D

	if right_barrier != null:
		var target_x := right_barrier.global_position.x - 70.0
		loop_trigger_x = target_x
		if trigger_area != null:
			trigger_area.global_position = Vector2(target_x, 300.0)
		if exit_blocker != null:
			exit_blocker.global_position = Vector2(target_x + 40.0, 300.0)
		if exit_fog != null:
			(exit_fog as Node2D).global_position = Vector2(target_x, 300.0)


func _physics_process(_delta: float) -> void:
	if is_loop_unlocked:
		return

	# Continuous coordinate boundary check for all characters in scene
	var root := get_tree().current_scene
	if root == null:
		return

	var player := root.get_node_or_null("Player") as CharacterBody2D
	var luca := root.get_node_or_null("Luca") as CharacterBody2D

	if player != null and player.global_position.x >= loop_trigger_x:
		_warp_body(player)
	if luca != null and luca.global_position.x >= loop_trigger_x:
		_warp_body(luca)


func _on_trigger_body_entered(body: Node2D) -> void:
	if is_loop_unlocked:
		return
	if body is CharacterBody2D or body.name == "Player" or body.name == "Luca":
		_warp_body(body)


func activate_signal() -> void:
	unlock_loop()


func unlock_loop() -> void:
	if is_loop_unlocked:
		return
	is_loop_unlocked = true
	_update_exit_state()
	signal_activated.emit()
	loop_unlocked.emit()


func lock_loop() -> void:
	is_loop_unlocked = false
	_update_exit_state()


func _warp_body(body: Node2D) -> void:
	if is_loop_unlocked:
		return

	var offset_x := loop_trigger_x - loop_return_x
	body.global_position.x -= offset_x

	if body is CharacterBody2D:
		var cb := body as CharacterBody2D
		# Maintain existing horizontal run velocity
		cb.velocity.y = minf(cb.velocity.y, 100.0)

	if body.has_method("reset_physics_interpolation"):
		body.call("reset_physics_interpolation")

	# Reset camera smoothing jump if camera is attached
	var cam := body.get_node_or_null("Camera2D") as Camera2D
	if cam != null:
		cam.reset_smoothing()

	total_loops += 1
	loop_triggered.emit(body, total_loops)
	_play_loop_vfx()


func _play_loop_vfx() -> void:
	var canvas_layer := get_node_or_null("../DreamShiftManager/CanvasLayer/TelegraphVignette") as CanvasItem
	if canvas_layer != null:
		canvas_layer.visible = true
		var tw := create_tween()
		tw.tween_property(canvas_layer, "modulate:a", 0.65, 0.1)
		tw.tween_property(canvas_layer, "modulate:a", 0.0, 0.4)
		tw.tween_callback(func() -> void: canvas_layer.visible = false)


func _update_exit_state() -> void:
	if exit_blocker != null:
		var col := exit_blocker.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if col != null:
			col.set_deferred("disabled", is_loop_unlocked)
		exit_blocker.visible = not is_loop_unlocked

	if exit_fog != null:
		var tw := create_tween()
		tw.tween_property(exit_fog, "modulate:a", 0.0 if is_loop_unlocked else 0.8, 0.5)
