class_name ForestInteriorLevel
extends DayLevelEnvironment

const COMPLETED_FLAG := "forest_interior_completed"
const DIRECT_LIFT_FLAG := "forest_interior_direct_lift_unlocked"
const FINAL_GATE_FLAG := "forest_interior_final_gate_open"
const CROWN_LEVEL_ID := &"forest_crown"
const CROWN_ENTRY_ID := &"from_interior"

@export var fall_damage := 10
@export var fade_out_time := 0.16
@export var fade_in_time := 0.24

@onready var player: CharacterBody2D = $Player
@onready var luca: CharacterBody2D = $Luca
@onready var party: Node = $ForestController/PartyController
@onready var luca_world_controller: Node = $ForestController/LucaWorldController
@onready var fade_rect: ColorRect = $UI/FadeRect
@onready var pressure_panel: Control = $UI/SprayPanel
@onready var pressure_bar: ProgressBar = $UI/SprayPanel/Margin/VBox/PressureBar
@onready var pressure_label: Label = $UI/SprayPanel/Margin/VBox/PressureLabel
@onready var corrupted_background: CanvasItem = $Background/CorruptedBackground
@onready var normal_background: CanvasItem = $Background/NormalBackground
@onready var blood_stream: CanvasItem = $Background/CentralStream/BloodStream
@onready var clear_stream: CanvasItem = $Background/CentralStream/ClearStream
@onready var direct_lift: Node = $LucaWorldOnly/UpperControlRoom/DirectLift
@onready var final_gate: Node = $RealityWorld/FinalGate

var _respawning := false
var _activated_consoles: Dictionary = {}
var _lift_power_nodes := {
	&"lift_root": false,
	&"lift_water": false,
	&"lift_crown": false,
}
var _respawn_positions: Dictionary = {}


func _enter_tree() -> void:
	_ensure_switch_character_input()


func _ready() -> void:
	super()
	fade_rect.modulate.a = 0.0
	pressure_panel.visible = false
	_respawn_positions[&"Player"] = $RespawnPoints/Bottom.global_position
	_respawn_positions[&"Luca"] = $RespawnPoints/Bottom.global_position + Vector2(90.0, 0.0)
	if party != null and party.has_method("enable_switching"):
		party.call("enable_switching", true)
	if luca_world_controller != null and luca_world_controller.has_method("set_luca_view"):
		luca_world_controller.call("set_luca_view", false)
	_apply_environment_state(start_corrupted, true)
	_restore_persistent_progress()
	_activate_travel_anchor()


func _activate_travel_anchor() -> void:
	var runtime := _get_day_runtime()
	if runtime != null and runtime.has_method("activate_travel_anchor"):
		runtime.call("activate_travel_anchor", &"forest_interior")
	elif get_player_data() != null:
		get_player_data().unlock_level(&"forest_interior")


func _ensure_switch_character_input() -> void:
	var action := &"switch_character"
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and (event.physical_keycode == KEY_C or event.keycode == KEY_C):
			return
	var key := InputEventKey.new()
	key.physical_keycode = KEY_C
	InputMap.action_add_event(action, key)


func set_corrupted(corrupted: bool) -> void:
	_apply_environment_state(corrupted)


func is_corrupted() -> bool:
	return _is_corrupted


func _apply_environment_state(corrupted: bool, force := false) -> void:
	if not force and _is_corrupted == corrupted:
		return
	_is_corrupted = corrupted
	corrupted_background.visible = corrupted
	normal_background.visible = not corrupted
	blood_stream.visible = corrupted
	clear_stream.visible = not corrupted
	for mud in get_tree().get_nodes_in_group("forest_mud"):
		if is_ancestor_of(mud) and mud.has_method("set_environment_corrupted"):
			mud.call("set_environment_corrupted", corrupted)
	if not corrupted:
		_apply_solved_traversal_state()
	if not force:
		environment_state_changed.emit(corrupted)


func is_luca_active() -> bool:
	if party != null and "active_character" in party:
		return party.active_character == &"luca"
	return luca != null and luca.get_node_or_null("Camera2D") != null


func set_party_switching(enabled: bool) -> void:
	if party != null and party.has_method("enable_switching"):
		party.call("enable_switching", enabled)


func activate_luca_console(action_id: StringName) -> bool:
	match action_id:
		&"root_lift_a":
			return _call_node("RealityWorld/RootLiftA", "toggle_state")
		&"rotate_beam":
			return _call_node("RealityWorld/RotatingRoot", "set_horizontal")
		&"sluice":
			return _call_node("RealityWorld/SluiceGate", "open_gate")
		&"root_lift_b":
			return _call_node("RealityWorld/RootLiftB", "toggle_state")
		&"lift_root", &"lift_water", &"lift_crown":
			_lift_power_nodes[action_id] = true
			_activated_consoles[action_id] = true
			_refresh_direct_lift()
			return true
		&"final_gate":
			_activated_consoles[action_id] = true
			if final_gate != null and final_gate.has_method("open_gate"):
				final_gate.call("open_gate")
			_set_flag(FINAL_GATE_FLAG, true)
			return true
		_:
			push_warning("ForestInterior: unknown Luca console action: %s" % action_id)
	return false


func is_console_activated(action_id: StringName) -> bool:
	return bool(_activated_consoles.get(action_id, false))


func _call_node(path: NodePath, method: StringName) -> bool:
	var node := get_node_or_null(path)
	if node == null or not node.has_method(method):
		push_warning("ForestInterior missing puzzle target %s.%s" % [path, method])
		return false
	node.call(method)
	return true


func _refresh_direct_lift() -> void:
	var unlocked := true
	for key in _lift_power_nodes:
		unlocked = unlocked and bool(_lift_power_nodes[key])
	if direct_lift != null and direct_lift.has_method("set_unlocked"):
		direct_lift.call("set_unlocked", unlocked)
	if unlocked:
		_set_flag(DIRECT_LIFT_FLAG, true)


func update_spray_ui(pressure: float, maximum: float, controlling: bool) -> void:
	pressure_panel.visible = controlling
	pressure_bar.max_value = maximum
	pressure_bar.value = pressure
	pressure_label.text = "水压  %d / %d" % [roundi(pressure), roundi(maximum)]


func register_respawn(body: Node2D, marker: Marker2D) -> void:
	if body == null or marker == null:
		return
	_respawn_positions[StringName(body.name)] = marker.global_position


func request_respawn(body: Node2D, reason: String = "fall", damage: int = -1) -> void:
	if _respawning or not is_instance_valid(body):
		return
	var amount := fall_damage if damage < 0 else damage
	var runtime := _get_day_runtime()
	if runtime != null and amount > 0 and runtime.call("apply_player_damage", amount, StringName(reason)):
		return
	_respawning = true
	set_party_switching(false)
	_set_character_control(body, false)
	if body is CharacterBody2D:
		body.velocity = Vector2.ZERO
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(fade_rect, "modulate:a", 1.0, fade_out_time)
	await tween.finished
	var key := StringName(body.name)
	var target: Vector2 = _respawn_positions.get(key, $RespawnPoints/Bottom.global_position)
	body.global_position = target
	if body is CharacterBody2D:
		body.velocity = Vector2.ZERO
	await get_tree().create_timer(0.05).timeout
	var tween_in := create_tween()
	tween_in.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween_in.tween_property(fade_rect, "modulate:a", 0.0, fade_in_time)
	await tween_in.finished
	_set_character_control(body, true)
	set_party_switching(true)
	_respawning = false


func _set_character_control(body: Node, enabled: bool) -> void:
	if body.has_method("set_control_enabled"):
		body.call("set_control_enabled", enabled)
		return
	if body.has_method("set_dialogue_locked"):
		body.call("set_dialogue_locked", not enabled)
	if body.has_method("set_potion_action_locked"):
		body.call("set_potion_action_locked", not enabled)


func request_exit_to_crown() -> void:
	_set_flag(COMPLETED_FLAG, true)
	var runtime := _get_day_runtime()
	if runtime != null:
		if runtime.has_method("transition_to_level_with_blackout"):
			runtime.call("transition_to_level_with_blackout", "forest_crown", &"from_interior", true)
		elif runtime.has_method("switch_to_level"):
			runtime.call("switch_to_level", CROWN_LEVEL_ID, CROWN_ENTRY_ID)
	else:
		get_tree().change_scene_to_file("res://day/levels/forest/crown/forest_crown.tscn")


func _restore_persistent_progress() -> void:
	if _get_flag(DIRECT_LIFT_FLAG):
		for key in _lift_power_nodes:
			_lift_power_nodes[key] = true
			_activated_consoles[key] = true
		_refresh_direct_lift()
	if _get_flag(FINAL_GATE_FLAG):
		_activated_consoles[&"final_gate"] = true
		if final_gate != null and final_gate.has_method("open_gate"):
			final_gate.call("open_gate", true)
	if _get_flag(COMPLETED_FLAG):
		_apply_solved_traversal_state()


func _apply_solved_traversal_state() -> void:
	var lift_a := get_node_or_null("RealityWorld/RootLiftA")
	if lift_a != null and lift_a.has_method("set_high"):
		lift_a.call("set_high", true)
	var beam := get_node_or_null("RealityWorld/RotatingRoot")
	if beam != null and beam.has_method("set_horizontal"):
		beam.call("set_horizontal", true)
	var sluice := get_node_or_null("RealityWorld/SluiceGate")
	if sluice != null and sluice.has_method("open_gate"):
		sluice.call("open_gate", true)
	var lift_b := get_node_or_null("RealityWorld/RootLiftB")
	if lift_b != null and lift_b.has_method("set_high"):
		lift_b.call("set_high", true)
	for key in _lift_power_nodes:
		_lift_power_nodes[key] = true
		_activated_consoles[key] = true
	_refresh_direct_lift()
	if final_gate != null and final_gate.has_method("open_gate"):
		final_gate.call("open_gate", true)


func _set_flag(key: String, value: bool) -> void:
	var data := get_player_data()
	if data != null:
		data.tutorial_flags[key] = value


func _get_flag(key: String) -> bool:
	var data := get_player_data()
	return data != null and bool(data.tutorial_flags.get(key, false))


func _get_day_runtime() -> Node:
	var cursor: Node = get_parent()
	while cursor != null:
		# Duck-typed: DayRuntime is identified by its switch_to_level API so this
		# script never needs to preload the DayRuntime class (which would create
		# a cyclic preload through DayRuntime.LEVELS).
		if cursor.has_method("switch_to_level"):
			return cursor
		cursor = cursor.get_parent()
	return null
