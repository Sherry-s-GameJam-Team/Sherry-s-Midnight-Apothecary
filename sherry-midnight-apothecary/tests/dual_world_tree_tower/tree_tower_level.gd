extends DayLevelEnvironment

const TOWER_BOTTOM := 3740.0
const STATE_PLATFORM_A := &"tree_platform_a_right"
const STATE_PLATFORM_B := &"tree_platform_b_high"
const STATE_PLATFORM_C := &"tree_platform_c_left"
const STATE_GROWTH := &"tree_growth_done"
const STATE_FREEZE := &"tree_freeze_done"
const STATE_BLAST := &"tree_blast_done"
const STATE_GOAL := &"tree_goal_reached"

@onready var manager: DualWorldManager = $Systems/DualWorldManager
@onready var protagonists: DualProtagonistController = $Systems/DualProtagonistController
@onready var state: DualWorldState = $Systems/DualWorldState
@onready var sherry: CharacterBody2D = $Actors/Sherry
@onready var luca: CharacterBody2D = $Actors/Luca
@onready var platform_a: AnimatableBody2D = $SharedWorld/SharedCollision/RemotePlatformA
@onready var platform_b: AnimatableBody2D = $SharedWorld/SharedCollision/RemotePlatformB
@onready var platform_c: AnimatableBody2D = $SharedWorld/SharedCollision/RemotePlatformC
@onready var root_steps: Array[Node] = [$CorruptedWorld/WorldObjects/RootStep1, $CorruptedWorld/WorldObjects/RootStep2]
@onready var sap_steps: Array[Node] = [$CorruptedWorld/WorldObjects/SapStep1, $CorruptedWorld/WorldObjects/SapStep2, $CorruptedWorld/WorldObjects/SapStep3]
@onready var rotten_barrier: Node2D = $CorruptedWorld/WorldObjects/RottenBarrier
@onready var goal: Area2D = $SharedWorld/SharedInteractables/TreeCrownGoal
@onready var status_label: Label = $UI/Panel/Status
@onready var objective_label: Label = $UI/Panel/Objective
@onready var progress_label: Label = $UI/Progress

var sherry_checkpoint := Vector2(760, 3614)
var _platform_tween: Tween


func _ready() -> void:
	super()
	protagonists.camera.limit_left = 0
	protagonists.camera.limit_right = 1280
	protagonists.camera.limit_top = 0
	protagonists.camera.limit_bottom = 4100
	state.state_changed.connect(_on_state_changed)
	manager.world_changed.connect(_on_world_changed)
	manager.world_collision_prepared.connect(_on_world_collision_prepared)
	protagonists.active_actor_changed.connect(_on_actor_changed)
	goal.body_entered.connect(_on_goal_body_entered)
	_refresh_state()


func _process(_delta: float) -> void:
	if sherry.global_position.y > TOWER_BOTTOM + 420.0:
		sherry.global_position = sherry_checkpoint
		sherry.velocity = Vector2.ZERO
		status_label.text = "Sherry fell and returned to the latest potion checkpoint."
	if luca.global_position.y > TOWER_BOTTOM + 420.0:
		luca.global_position = Vector2(680, 3690)
		luca.velocity = Vector2.ZERO


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_E:
		_try_luca_console()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F:
		_try_sherry_potion()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_R:
		get_tree().reload_current_scene()
		get_viewport().set_input_as_handled()


func _try_luca_console() -> void:
	if protagonists.active_actor != DualProtagonistController.Actor.LUCA:
		status_label.text = "Only Luca can use the lower control-room consoles."
		return
	var console_id := _nearest_id({&"A": Vector2(205, 3650), &"B": Vector2(310, 3650), &"C": Vector2(415, 3650)}, luca.global_position, 105.0)
	if console_id == &"":
		status_label.text = "Move Luca beside console A, B, or C."
		return
	operate_console(console_id)


func operate_console(console_id: StringName) -> bool:
	match console_id:
		&"A":
			state.set_flag(STATE_PLATFORM_A, not state.is_flag_set(STATE_PLATFORM_A))
			var target_a := Vector2(240, 3392)
			if state.is_flag_set(STATE_PLATFORM_A):
				target_a = Vector2(690, 3392)
			_move_platform(platform_a, target_a)
		&"B":
			state.set_flag(STATE_PLATFORM_B, not state.is_flag_set(STATE_PLATFORM_B))
			var target_b := Vector2(690, 2632)
			if state.is_flag_set(STATE_PLATFORM_B):
				target_b = Vector2(690, 2482)
			_move_platform(platform_b, target_b)
		&"C":
			state.set_flag(STATE_PLATFORM_C, not state.is_flag_set(STATE_PLATFORM_C))
			var target_c := Vector2(1030, 1582)
			if state.is_flag_set(STATE_PLATFORM_C):
				target_c = Vector2(575, 1582)
			_move_platform(platform_c, target_c)
		_:
			return false
	status_label.text = "Luca changed remote platform %s." % console_id
	_refresh_ui()
	return true


func _try_sherry_potion() -> void:
	if protagonists.active_actor != DualProtagonistController.Actor.SHERRY:
		status_label.text = "Only Sherry can activate potion receptors."
		return
	var potion_id := _nearest_id({&"GROWTH": Vector2(970, 3175), &"FREEZE": Vector2(960, 2270), &"BLAST": Vector2(965, 1370)}, sherry.global_position, 125.0)
	if potion_id == &"":
		status_label.text = "Move Sherry beside a potion receptor."
		return
	activate_potion(potion_id)


func activate_potion(potion_id: StringName) -> bool:
	match potion_id:
		&"GROWTH":
			if state.is_flag_set(STATE_GROWTH):
				return false
			state.set_flag(STATE_GROWTH)
			sherry_checkpoint = Vector2(925, 3160)
		&"FREEZE":
			if state.is_flag_set(STATE_FREEZE):
				return false
			state.set_flag(STATE_FREEZE)
			sherry_checkpoint = Vector2(900, 2255)
		&"BLAST":
			if state.is_flag_set(STATE_BLAST):
				return false
			state.set_flag(STATE_BLAST)
			sherry_checkpoint = Vector2(900, 1355)
		_:
			return false
	status_label.text = "Sherry activated the %s potion receptor." % potion_id
	_refresh_state()
	return true


func _move_platform(platform: AnimatableBody2D, target: Vector2) -> void:
	var delta_move := target - platform.global_position
	var carry_sherry := absf(sherry.global_position.x - platform.global_position.x) <= 135.0 and absf(sherry.global_position.y - (platform.global_position.y - 95.0)) <= 105.0
	if _platform_tween != null and _platform_tween.is_valid():
		_platform_tween.kill()
	_platform_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_platform_tween.tween_property(platform, "global_position", target, 0.55)
	if carry_sherry:
		_platform_tween.tween_property(sherry, "global_position", sherry.global_position + delta_move, 0.55)


func _nearest_id(items: Dictionary, actor_position: Vector2, max_distance: float) -> StringName:
	var nearest := &""
	var nearest_distance := max_distance
	for key: Variant in items:
		var distance := actor_position.distance_to(items[key] as Vector2)
		if distance <= nearest_distance:
			nearest = StringName(key)
			nearest_distance = distance
	return nearest


func _on_state_changed(_key: StringName, _value: Variant) -> void:
	_refresh_state()


func _on_world_changed(_world: DualWorldManager.WorldState) -> void:
	_refresh_state()


func _on_world_collision_prepared(world: DualWorldManager.WorldState, enabled: bool) -> void:
	if world == DualWorldManager.WorldState.CORRUPTED:
		_apply_corrupted_collision(enabled)


func _on_actor_changed(_actor: DualProtagonistController.Actor) -> void:
	_refresh_ui()


func _on_goal_body_entered(body: Node) -> void:
	if body == sherry and state.is_flag_set(STATE_BLAST):
		state.set_flag(STATE_GOAL)


func _refresh_state() -> void:
	for step: Node in root_steps:
		step.visible = state.is_flag_set(STATE_GROWTH)
	for step: Node in sap_steps:
		step.visible = state.is_flag_set(STATE_FREEZE)
	rotten_barrier.visible = not state.is_flag_set(STATE_BLAST)
	_apply_corrupted_collision(manager.current_world == DualWorldManager.WorldState.CORRUPTED)
	_refresh_ui()


func _apply_corrupted_collision(world_enabled: bool) -> void:
	for step: Node in root_steps:
		_set_collision_tree(step, world_enabled and state.is_flag_set(STATE_GROWTH))
	for step: Node in sap_steps:
		_set_collision_tree(step, world_enabled and state.is_flag_set(STATE_FREEZE))
	_set_collision_tree(rotten_barrier, world_enabled and not state.is_flag_set(STATE_BLAST))


func _set_collision_tree(node: Node, enabled: bool) -> void:
	if node is CollisionShape2D or node is CollisionPolygon2D:
		node.set_deferred("disabled", not enabled)
	for child: Node in node.get_children():
		_set_collision_tree(child, enabled)


func _refresh_ui() -> void:
	if not is_node_ready():
		return
	if state.is_flag_set(STATE_GOAL):
		objective_label.text = "COMPLETE: Sherry reached the tree crown. R resets the tower."
	elif not state.is_flag_set(STATE_GROWTH):
		objective_label.text = "Luca moves A right; Sherry climbs to GROWTH and presses F."
	elif not state.is_flag_set(STATE_FREEZE):
		objective_label.text = "Luca raises B; Sherry reaches FREEZE and presses F."
	elif not state.is_flag_set(STATE_BLAST):
		objective_label.text = "Luca moves C left; Sherry reaches BLAST and presses F."
	else:
		objective_label.text = "Rotten bark is gone. Sherry climbs to the tree-crown exit."
	var actor_name := "SHERRY / CORRUPTED ASCENT"
	if protagonists.active_actor == DualProtagonistController.Actor.LUCA:
		actor_name = "LUCA / ORIGINAL CONTROL ROOM"
	status_label.text = "Active: %s — Q switch, E console, F potion, R reset" % actor_name
	var platform_a_text := "LEFT"
	var platform_b_text := "LOW"
	var platform_c_text := "RIGHT"
	if state.is_flag_set(STATE_PLATFORM_A):
		platform_a_text = "RIGHT"
	if state.is_flag_set(STATE_PLATFORM_B):
		platform_b_text = "HIGH"
	if state.is_flag_set(STATE_PLATFORM_C):
		platform_c_text = "LEFT"
	progress_label.text = "A:%s  B:%s  C:%s\nGROWTH:%s  FREEZE:%s  BLAST:%s" % [
		platform_a_text,
		platform_b_text,
		platform_c_text,
		_flag_text(STATE_GROWTH),
		_flag_text(STATE_FREEZE),
		_flag_text(STATE_BLAST),
	]


func _flag_text(key: StringName) -> String:
	if state.is_flag_set(key):
		return "ON"
	return "OFF"
