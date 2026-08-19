class_name AuremClocktowerInsideLevel
extends DayLevelEnvironment

signal objective_updated(text: String, hint: String)
signal clocktower_synchronized

@export var current_floor_checkpoint: int = 1
@export var is_tower_synchronized: bool = false

var _checkpoints: Dictionary = {
	1: Vector2(500, 480),
	2: Vector2(300, -850),
	3: Vector2(300, -2000),
	4: Vector2(300, -3200),
	5: Vector2(500, -4350),
}

var _is_respawning: bool = false

@onready var audio_synth: Node = get_node_or_null("ClocktowerAudio")
@onready var floor1: Node2D = get_node_or_null("World/Floor1_SpringChamber")
@onready var floor2: Node2D = get_node_or_null("World/Floor2_GearWell")
@onready var floor3: Node2D = get_node_or_null("World/Floor3_PendulumHall")
@onready var floor4: Node2D = get_node_or_null("World/Floor4_ClockHands")
@onready var tower_top: Node2D = get_node_or_null("World/TowerTop")

@onready var calib_node_1: Area2D = get_node_or_null("World/Floor1_SpringChamber/CalibrationNode1")
@onready var calib_node_2: Area2D = get_node_or_null("World/Floor2_GearWell/CalibrationNode2")
@onready var calib_node_3: Area2D = get_node_or_null("World/Floor3_PendulumHall/CalibrationNode3")

@onready var fade_overlay: CanvasModulate = get_node_or_null("FadeOverlay")


func _ready() -> void:
	super._ready()
	add_to_group("clocktower_inside")

	if calib_node_1 != null and calib_node_1.has_signal("fixed"):
		calib_node_1.connect("fixed", _on_node_1_fixed)
	if calib_node_2 != null and calib_node_2.has_signal("fixed"):
		calib_node_2.connect("fixed", _on_node_2_fixed)
	if calib_node_3 != null and calib_node_3.has_signal("fixed"):
		calib_node_3.connect("fixed", _on_node_3_fixed)
	if tower_top != null and tower_top.has_signal("synchronization_completed"):
		tower_top.connect("synchronization_completed", _on_grand_synchronization)

	objective_updated.emit("深入巨钟塔发条室。", "观察机械脉冲节奏，修复主发条限位器。")


var _camera: Camera2D = null
var _player: Node2D = null


func _process(delta: float) -> void:
	if _camera == null:
		if _player == null:
			_player = get_node_or_null("Player")
		if _player != null:
			_camera = _player.get_node_or_null("Camera2D") as Camera2D

	if _camera != null and _player != null:
		var player_y: float = _player.global_position.y
		# 到第三层 (Y: -1850 ~ -3200) 摄像机上移 150px (offset.y = -150)，直到触发第四层
		var in_floor3: bool = (player_y <= -1850.0 and player_y > -3200.0 and current_floor_checkpoint < 4)
		var target_offset_y: float = -150.0 if in_floor3 else 0.0
		_camera.offset.y = move_toward(_camera.offset.y, target_offset_y, 400.0 * delta)


func on_level_entered(entry_id: StringName) -> void:
	match String(entry_id):
		"floor2":
			current_floor_checkpoint = 2
		"floor3":
			current_floor_checkpoint = 3
		"floor4":
			current_floor_checkpoint = 4
		"top":
			current_floor_checkpoint = 5
		_:
			current_floor_checkpoint = 1


func _on_node_1_fixed(_id: int) -> void:
	current_floor_checkpoint = 2
	if floor1 != null and floor1.has_method("set_stabilized"):
		floor1.call("set_stabilized", true)
	objective_updated.emit("登上第二层：齿轮井。", "拉动校准杆同步齿轮相位，修复齿轮差速器。")


func _on_node_2_fixed(_id: int) -> void:
	current_floor_checkpoint = 3
	objective_updated.emit("登上第三层：钟摆厅。", "聆听钟声预兆并观察节拍灯，搭乘钟摆跨越深壑。")


func _on_node_3_fixed(_id: int) -> void:
	current_floor_checkpoint = 4
	if floor3 != null:
		var pendulum := floor3.get_node_or_null("SwingingPendulum")
		if pendulum != null and pendulum.has_method("set_stabilized"):
			pendulum.call("set_stabilized", true)
	objective_updated.emit("登上第四层：指针层。", "转动手轮调校钟面指针，前往塔顶校时台。")


func _on_grand_synchronization() -> void:
	is_tower_synchronized = true
	clocktower_synchronized.emit()

	var data := get_player_data()
	if data != null and data.tutorial_flags != null:
		data.tutorial_flags["aurem_clockyard_tower_synchronized"] = true

	objective_updated.emit("奥雷姆钟庭已重新同步！", "通过时律界门返回。")


func request_fall_respawn(player_body: Node2D, floor_id: int, damage: int) -> void:
	if _is_respawning:
		return
	_is_respawning = true

	var death_handled := apply_player_damage(damage, &"clocktower_fall")
	if not death_handled:
		var spawn_pos: Vector2 = _checkpoints.get(maxi(current_floor_checkpoint, floor_id), Vector2(500, 480))
		player_body.global_position = spawn_pos
		if player_body is CharacterBody2D:
			(player_body as CharacterBody2D).velocity = Vector2.ZERO
		if player_body.has_method("reset_physics_interpolation"):
			player_body.call("reset_physics_interpolation")

		var tree := get_tree()
		if tree != null:
			await tree.create_timer(0.3).timeout

	_is_respawning = false


func apply_fall_or_hazard_damage(damage: int, reason: String) -> void:
	apply_player_damage(damage, StringName(reason))
