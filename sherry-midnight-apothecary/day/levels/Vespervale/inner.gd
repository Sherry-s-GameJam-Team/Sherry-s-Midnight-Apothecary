class_name VespervaleInnerLevel
extends DayLevelEnvironment

## Vespervale Inner Dream Hospital Ward Corridor (梦疗院·病栋回廊).
## 2D dual-layer cooperative gauntlet featuring rhythmic Dream / Reality Intrusion cycles,
## C-key character switching (Sherry on lower corridor, Luca on upper observation catwalks),
## reciprocal window unlocking, hazard evasion, and marrow node purification.

signal objective_updated(text: String, hint: String)
signal level_completed

@export var is_ward_cleansed: bool = false
@export var default_spawn_position: Vector2 = Vector2(250, 520)
@export var luca_spawn_position: Vector2 = Vector2(300, 290)

var _is_respawning: bool = false

@onready var dream_shift_manager: DreamShiftManager = get_node_or_null("DreamShiftManager")
@onready var party_controller: InnerPartyController = get_node_or_null("InnerPartyController")
@onready var corridor_manager: EndlessCorridorManager = get_node_or_null("EndlessCorridorManager")
@onready var signal_beacon: SignalBeacon = get_node_or_null("World/Mechanisms/SignalBeacon")
@onready var marrow_node: DreamMarrowNode = get_node_or_null("World/Mechanisms/DreamMarrowNode")
@onready var exit_door: WardExitDoor = get_node_or_null("World/Mechanisms/WardExitDoor")
@onready var exit_portal: DoorPortal = get_node_or_null("World/Portals/ExitPortal")


func _ready() -> void:
	super._ready()
	add_to_group("vespervale_inner")

	# Ensure party controller exists if not manually instantiated in scene
	if party_controller == null:
		party_controller = InnerPartyController.new()
		party_controller.name = "InnerPartyController"
		add_child(party_controller)

	# Ensure party switch HUD exists
	if get_node_or_null("InnerPartySwitchUI") == null:
		var switch_ui := InnerPartySwitchUI.new()
		switch_ui.name = "InnerPartySwitchUI"
		add_child(switch_ui)

	if corridor_manager != null:
		corridor_manager.loop_triggered.connect(_on_corridor_loop_triggered)
		corridor_manager.loop_unlocked.connect(_on_corridor_loop_unlocked)

	if signal_beacon != null:
		signal_beacon.beacon_activated.connect(_on_beacon_activated)

	if marrow_node != null:
		marrow_node.activated.connect(_on_marrow_node_activated)

	objective_updated.emit(
		"深入梦疗院·无尽回廊。",
		"回廊受神秘空间折叠笼罩：除非激活破界信号，否则向右前进将无尽折返！"
	)


func _on_corridor_loop_triggered(_body: Node2D, total_loops: int) -> void:
	objective_updated.emit(
		"空间再次折叠（循环第 %d 次）" % total_loops,
		"回廊在无尽循环！寻找并激活场景中的【破界信号终端】以打破空间闭环。"
	)


func _on_beacon_activated() -> void:
	if corridor_manager != null:
		corridor_manager.activate_signal()


func _on_corridor_loop_unlocked() -> void:
	objective_updated.emit(
		"破界信号已激活！",
		"空间闭环已消解，向右前行前往出口脱离回廊。"
	)


func _on_marrow_node_activated() -> void:
	if exit_door != null:
		exit_door.unlock()

	if corridor_manager != null:
		corridor_manager.unlock_loop()

	var grasp_mgr := get_node_or_null("DreamGraspManager")
	if grasp_mgr != null and grasp_mgr.has_method("force_lurk"):
		grasp_mgr.call("force_lurk")

	var end_barrier := get_node_or_null("World/Architecture/EndDropBarrier")
	if end_barrier != null and end_barrier.has_method("open"):
		end_barrier.call("open")

	is_ward_cleansed = true
	level_completed.emit()

	var data := get_player_data()
	if data != null and data.tutorial_flags != null:
		data.tutorial_flags["vespervale_inner_cleared"] = true

	objective_updated.emit("病栋梦髓已净化！", "梦境壁垒消融，卢卡与雪莉前往右侧终点传送门。")


func request_fall_respawn(player_body: Node2D, _checkpoint_id: int = 0, damage: int = 1) -> void:
	if _is_respawning:
		return
	_is_respawning = true

	var death_handled := apply_player_damage(damage, &"inner_ward_hazard")
	if not death_handled:
		var spawn_pos := luca_spawn_position if (player_body != null and player_body.name == "Luca") else default_spawn_position
		player_body.global_position = spawn_pos
		if player_body is CharacterBody2D:
			(player_body as CharacterBody2D).velocity = Vector2.ZERO
		if player_body.has_method("reset_physics_interpolation"):
			player_body.call("reset_physics_interpolation")

		var tree := get_tree()
		if tree != null:
			await tree.create_timer(0.3).timeout

	_is_respawning = false


func _find_top_hint() -> Node:
	var cur: Node = self
	var hint := cur.get_node_or_null("PauseMenuLayer/TopHintUI")
	if hint == null:
		hint = cur.get_node_or_null("TopHintUI")
	return hint
