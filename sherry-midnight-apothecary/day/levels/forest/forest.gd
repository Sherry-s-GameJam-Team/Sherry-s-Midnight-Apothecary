class_name ForestEnvironment
extends DayLevelEnvironment

signal phase_changed(phase: int)
signal checkpoint_requested(checkpoint_id: StringName)
signal waterwheel_progress_changed(active_count: int, total_count: int)

const TREE_GATE_FLAG := "forest_tree_gate_opened"
const FOREST_COMPLETED_FLAG := "forest_completed"
const DIRECT_LIFT_FLAG := "forest_direct_lift_unlocked"
const CONTROL_FLAGS := ["forest_root_control", "forest_water_pressure_control", "forest_crown_gate_control"]

enum ForestPhase { EXTERIOR, TREE_GATE_OPEN, INTERIOR, CROWN, BOSS, RESTORED }

@export var debug_mode := false
@export var exterior_respawn := Vector2(420, 560)
@export var interior_respawn := Vector2(7180, 380)

var phase := ForestPhase.EXTERIOR
var tree_gate_opened := false
var direct_lift_unlocked := false
var boss_started := false
var boss_purified := false
var _wheel_ids: Dictionary = {}
var _interior_controls: Dictionary = {}
var _respawning := false

@onready var player: CharacterBody2D = $Player
@onready var luca: CharacterBody2D = $Luca
@onready var camera: Camera2D = $Player/Camera2D
@onready var party: ForestPartyController = $ForestController/PartyController
@onready var gate: ForestArvisTreeGate = $Exterior/ArvisTreeGate
@onready var direct_lift: ForestDirectLift = get_node_or_null("Interior/LucaWorldOnly/DirectLift")
@onready var stream_corrupted: CanvasItem = get_node_or_null("Interior/BloodStream")
@onready var stream_normal: CanvasItem = get_node_or_null("Interior/ClearStream")
@onready var wheel_label: Label = $UI/Margin/VBox/WaterwheelCounter
@onready var character_label: Label = $UI/Margin/VBox/Character
@onready var pressure_label: Label = $UI/Margin/VBox/Pressure
@onready var herb_spawns: Node2D = $Exterior/HerbSpawns
@onready var herb_director: Node2D = $Exterior/HerbSpawnDirector

func _ready() -> void:
	super()
	player.add_to_group("player")
	player.add_to_group("forest_character")
	_load_persistent_state()
	_connect_runtime_nodes()
	_apply_persistent_state()
	_set_phase(ForestPhase.RESTORED if boss_purified else ForestPhase.EXTERIOR)
	_update_ui()

func _process(_delta: float) -> void:
	if phase >= ForestPhase.INTERIOR and phase < ForestPhase.RESTORED:
		_update_pressure_ui()

func set_corrupted(corrupted: bool) -> void:
	if _is_corrupted == corrupted:
		return
	_is_corrupted = corrupted
	_apply_corruption_visuals()
	if has_signal("environment_state_changed"):
		environment_state_changed.emit(corrupted)

func is_corrupted() -> bool:
	return _is_corrupted

func to_normal() -> void:
	set_corrupted(false)

func to_corrupted() -> void:
	set_corrupted(true)

func register_waterwheel(wheel_id: StringName) -> void:
	if _wheel_ids.has(wheel_id):
		return
	_wheel_ids[wheel_id] = true
	waterwheel_progress_changed.emit(_wheel_ids.size(), 4)
	_update_ui()
	if _wheel_ids.size() >= 4 and not tree_gate_opened:
		gate.set_ready_to_open(true)

func activate_interior_control(control_id: StringName) -> void:
	if _interior_controls.has(control_id):
		return
	_interior_controls[control_id] = true
	_store_flag("forest_%s" % String(control_id), true)
	if _interior_controls.size() >= 3:
		unlock_direct_lift()

func unlock_direct_lift() -> void:
	if direct_lift_unlocked:
		return
	direct_lift_unlocked = true
	if direct_lift != null:
		direct_lift.set_unlocked(true)
	_store_flag(DIRECT_LIFT_FLAG, true)

func open_final_passage() -> void:
	var final_passage := get_node_or_null("Interior/FinalPassage")
	if final_passage == null:
		return
	var collision := final_passage.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		collision.set_deferred("disabled", true)
	final_passage.visible = false

func complete_restoration() -> void:
	boss_purified = true
	boss_started = false
	_store_flag(FOREST_COMPLETED_FLAG, true)
	set_corrupted(false)
	_set_phase(ForestPhase.RESTORED)
	gate.restore_open()
	for mud: Node in get_tree().get_nodes_in_group("forest_mud"):
		if is_ancestor_of(mud) and mud.has_method("restore_purified"):
			mud.call("restore_purified")
	var boss_trigger := get_node_or_null("Crown/BossTrigger") as Area2D
	if boss_trigger != null:
		boss_trigger.monitoring = false
	_enable_gathering(true)

func request_checkpoint(checkpoint_id: StringName) -> void:
	checkpoint_requested.emit(checkpoint_id)
	var runtime := _get_day_runtime()
	if runtime != null and runtime.has_method("request_checkpoint"):
		runtime.call("request_checkpoint", checkpoint_id)

func request_respawn(body: Node2D, reason: StringName, damage: int) -> void:
	if _respawning or not is_instance_valid(body):
		return
	var runtime := _get_day_runtime()
	if runtime != null and damage > 0 and runtime.has_method("apply_player_damage"):
		if bool(runtime.call("apply_player_damage", damage, reason)):
			return
	_respawning = true
	_set_body_control(body, false)
	if body is CharacterBody2D:
		body.velocity = Vector2.ZERO
	var target := _interior_respawn_for(body) if phase >= ForestPhase.INTERIOR and phase < ForestPhase.CROWN else exterior_respawn
	body.global_position = target
	await get_tree().physics_frame
	_set_body_control(body, true)
	_respawning = false

func enter_interior(body: Node2D) -> void:
	if not tree_gate_opened or body != player:
		return
	# The interior is now a standalone level registered in DayRuntime.LEVELS
	# (res://day/levels/forest/interior/forest_interior_level.tres). Hand off to
	# it instead of driving the old embedded interior phase in place.
	var runtime := _get_day_runtime()
	if runtime != null:
		if runtime.has_method("transition_to_level_with_blackout"):
			runtime.call("transition_to_level_with_blackout", "forest_interior", &"from_forest", true)
		elif runtime.has_method("switch_to_level"):
			runtime.call("switch_to_level", "forest_interior", &"from_forest")
	elif get_tree() != null and get_tree().current_scene == self:
		get_tree().change_scene_to_file("res://day/levels/forest/interior/forest_interior.tscn")

func enter_crown(body: Node2D) -> void:
	var sherry_entry := get_node_or_null("Crown/SherryEntry") as Marker2D
	var luca_entry := get_node_or_null("Crown/LucaEntry") as Marker2D
	if body == player and sherry_entry != null:
		player.global_position = sherry_entry.global_position
		_set_phase(ForestPhase.CROWN)
	elif body == luca and luca_entry != null:
		luca.global_position = luca_entry.global_position
		_apply_camera_for_active_character()

func _open_tree_gate() -> void:
	if tree_gate_opened or _wheel_ids.size() < 4:
		return
	tree_gate_opened = true
	_store_flag(TREE_GATE_FLAG, true)
	_set_phase(ForestPhase.TREE_GATE_OPEN)
	await gate.open_gate(false)
	request_checkpoint(&"forest_tree_gate_opened")
	var interior_entrance := get_node_or_null("Exterior/InteriorEntrance") as Area2D
	if interior_entrance != null and interior_entrance.overlaps_body(player):
		enter_interior(player)

func _connect_runtime_nodes() -> void:
	for wheel: Node in $Exterior/Waterwheels.get_children():
		if wheel.has_signal("activated"):
			wheel.activated.connect(register_waterwheel)
	gate.open_requested.connect(_open_tree_gate)
	var interior_entrance := get_node_or_null("Exterior/InteriorEntrance") as Area2D
	if interior_entrance != null:
		interior_entrance.body_entered.connect(enter_interior)
	var crown_entrance := get_node_or_null("Interior/CrownEntrance") as Area2D
	if crown_entrance != null:
		crown_entrance.body_entered.connect(enter_crown)
	if direct_lift != null:
		direct_lift.luca_lift_requested.connect(_on_luca_lift_requested)
	party.active_character_changed.connect(_on_active_character_changed)
	for control_name: String in ["RootControlSwitch", "WaterPressureSwitch", "CrownGateSwitch"]:
		var control := get_node_or_null("Interior/LucaWorldOnly/%s" % control_name)
		if control != null and control.has_signal("activated"):
			control.activated.connect(_on_control_switch_activated)
	var final_switch := get_node_or_null("Interior/LucaWorldOnly/FinalSwitch")
	if final_switch != null and final_switch.has_signal("activated"):
		final_switch.activated.connect(func(_id): open_final_passage())
	$BossInterface.boss_started.connect(_on_boss_started)

func _on_control_switch_activated(control_id: StringName) -> void:
	activate_interior_control(control_id)

func _on_luca_lift_requested(body: Node2D) -> void:
	if direct_lift_unlocked and body == luca:
		enter_crown(luca)

func _on_active_character_changed(_id: StringName) -> void:
	_apply_camera_for_active_character()
	_update_ui()

func _on_boss_started() -> void:
	boss_started = true
	_set_phase(ForestPhase.BOSS)

func _apply_camera_for_active_character() -> void:
	var body := party.active_body()
	if body.global_position.x >= 8800.0:
		_set_camera_limits(Rect2(8800, -200, 3000, 1000))
	elif body.global_position.x >= 6600.0:
		_set_camera_limits(Rect2(6600, -3400, 2000, 4200))
	else:
		_set_camera_limits(Rect2(0, 0, 6500, 724))

func _set_phase(value: int) -> void:
	phase = value
	match phase:
		ForestPhase.EXTERIOR, ForestPhase.TREE_GATE_OPEN:
			_set_camera_limits(Rect2(0, 0, 6500, 724))
		ForestPhase.INTERIOR:
			_set_camera_limits(Rect2(6600, -3400, 2000, 4200))
		ForestPhase.CROWN, ForestPhase.BOSS, ForestPhase.RESTORED:
			_set_camera_limits(Rect2(8800, -200, 3000, 1000))
	phase_changed.emit(phase)

func _set_camera_limits(rect: Rect2) -> void:
	camera.limit_left = int(rect.position.x)
	camera.limit_top = int(rect.position.y)
	camera.limit_right = int(rect.end.x)
	camera.limit_bottom = int(rect.end.y)

func _load_persistent_state() -> void:
	tree_gate_opened = _read_flag(TREE_GATE_FLAG)
	boss_purified = _read_flag(FOREST_COMPLETED_FLAG)
	direct_lift_unlocked = _read_flag(DIRECT_LIFT_FLAG)
	for flag: String in CONTROL_FLAGS:
		if _read_flag(flag):
			_interior_controls[StringName(flag.trim_prefix("forest_"))] = true
	_is_corrupted = start_corrupted and not boss_purified

func _apply_persistent_state() -> void:
	_apply_corruption_visuals()
	_enable_gathering(boss_purified)
	if tree_gate_opened or boss_purified:
		gate.restore_open()
		for wheel: Node in $Exterior/Waterwheels.get_children():
			if wheel.has_method("restore_active"):
				wheel.call("restore_active")
				_wheel_ids[wheel.get("wheel_id")] = true
	elif _wheel_ids.size() >= 4:
		gate.set_ready_to_open(true)
	if direct_lift != null and direct_lift_unlocked:
		direct_lift.set_unlocked(true)
	elif direct_lift != null:
		direct_lift.set_unlocked(false)
	luca.visible = false

func _apply_corruption_visuals() -> void:
	if stream_corrupted != null:
		stream_corrupted.visible = _is_corrupted
	if stream_normal != null:
		stream_normal.visible = not _is_corrupted
	var seraph_corrupted := get_node_or_null("Crown/SeraphCorrupted") as CanvasItem
	if seraph_corrupted != null:
		seraph_corrupted.visible = _is_corrupted and not boss_purified
	var seraph_normal := get_node_or_null("Crown/SeraphNormal") as CanvasItem
	if seraph_normal != null:
		seraph_normal.visible = not _is_corrupted
	$Exterior/CorruptionTint.visible = _is_corrupted

func _enable_gathering(enabled: bool) -> void:
	herb_spawns.visible = enabled
	herb_director.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED

func _update_ui() -> void:
	wheel_label.text = "水车 %d / 4" % _wheel_ids.size()
	character_label.text = "当前：%s" % ("Luca" if party.active_character == &"luca" else "Sherry")
	_update_pressure_ui()

func _update_pressure_ui() -> void:
	var spray: ForestSprayDevice = get_node_or_null("Interior/LucaWorldOnly/SprayDevice")
	if spray == null:
		pressure_label.visible = false
		return
	pressure_label.text = "水压 %d / %d   CD %.1fs" % [int(spray.pressure), int(spray.max_pressure), spray.cooldown_remaining()]
	pressure_label.visible = party.active_character == &"luca" and phase >= ForestPhase.INTERIOR

func _read_flag(flag: String) -> bool:
	var data := get_player_data()
	return data != null and bool(data.tutorial_flags.get(flag, false))

func _store_flag(flag: String, value: bool) -> void:
	var data := get_player_data()
	if data != null:
		data.tutorial_flags[flag] = value

func _get_day_runtime() -> Node:
	var cursor: Node = get_parent()
	while cursor != null:
		if cursor.has_method("switch_to_level") or cursor.has_method("transition_to_level_with_blackout") or cursor.has_method("apply_player_damage"):
			return cursor
		cursor = cursor.get_parent()
	return null

func _set_body_control(body: Node, enabled: bool) -> void:
	if body.has_method("set_control_enabled"):
		body.call("set_control_enabled", enabled)
	elif body.has_method("set_dialogue_locked"):
		body.call("set_dialogue_locked", not enabled)

func _interior_respawn_for(body: Node2D) -> Vector2:
	var marker_name := "RespawnBottom"
	if body.global_position.y < -2100.0:
		marker_name = "RespawnUpper"
	elif body.global_position.y < -900.0:
		marker_name = "RespawnMid"
	var marker := get_node_or_null("Interior/%s" % marker_name) as Marker2D
	return marker.global_position if marker != null else interior_respawn
