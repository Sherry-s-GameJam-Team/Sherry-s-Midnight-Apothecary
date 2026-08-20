class_name HelionBossArena
extends Node2D
## Arena controller for the Helion boss fight.
## Manages trigger gear, clock bird spawning, purify supply point,
## and bridges boss signals to the level controller (inside.gd).
## Does NOT extend DayLevelEnvironment — that is the parent level's job.

signal boss_started
signal boss_defeated(boss_id: StringName)

@export var boss_path: NodePath = ^"HelionBoss"
@export var clock_floor_path: NodePath = ^"ClockFloor"
@export var trigger_gear_path: NodePath = ^"TriggerGear"
@export var purify_supply_path: NodePath = ^"PurifySupplyPoint"
@export var player_spawn_path: NodePath = ^"PlayerSpawn"
@export var last_safe_marker_path: NodePath = ^"LastSafeMarker"

var is_battle_active: bool = false
var _boss: Node2D = null
var _clock_floor: Node2D = null
var _trigger_gear: Area2D = null
var _purify_supply: Node2D = null
var _player_spawn: Marker2D = null
var _last_safe_marker: Marker2D = null
var _arena_bounds_body: StaticBody2D = null
var _hud: CanvasLayer = null

# Clock bird tracking
var _active_clock_birds: Array[Node] = []
var _clock_bird_timer: float = 0.0

# Arena dimensions (local coordinates relative to this node)
@export var arena_width: float = 1200.0
@export var arena_height: float = 800.0


func _ready() -> void:
	_boss = get_node_or_null(boss_path) as Node2D
	_clock_floor = get_node_or_null(clock_floor_path) as Node2D
	_trigger_gear = get_node_or_null(trigger_gear_path) as Area2D
	_purify_supply = get_node_or_null(purify_supply_path) as Node2D
	_player_spawn = get_node_or_null(player_spawn_path) as Marker2D
	_last_safe_marker = get_node_or_null(last_safe_marker_path) as Marker2D
	_arena_bounds_body = get_node_or_null("ArenaBounds") as StaticBody2D
	_hud = get_node_or_null("BossHUD") as CanvasLayer

	# Connect trigger gear
	if _trigger_gear != null and _trigger_gear.has_signal("activated"):
		_trigger_gear.connect("activated", _on_trigger_gear_activated)

	# Connect boss signals
	if _boss != null:
		if _boss.has_signal("boss_defeated"):
			_boss.connect("boss_defeated", _on_boss_defeated)
		if _boss.has_signal("phase_changed"):
			_boss.connect("phase_changed", _on_boss_phase_changed)
		if _boss.has_method("set_arena"):
			_boss.call("set_arena", self)
		if _hud != null and _hud.has_method("connect_boss"):
			_hud.call("connect_boss", _boss)

	# Set up rewind recorder fallback position
	if _boss != null and _last_safe_marker != null:
		var recorder: Node = _boss.get_node_or_null("RewindRecorder")
		if recorder != null:
			recorder.set("fallback_position", _last_safe_marker.global_position)

	# Purify supply starts hidden
	if _purify_supply != null:
		_purify_supply.visible = false
		if _purify_supply is Area2D:
			(_purify_supply as Area2D).monitoring = false


func _on_trigger_gear_activated() -> void:
	trigger_boss_battle()


func trigger_boss_battle(player_node: Node2D = null) -> void:
	if is_battle_active:
		return

	is_battle_active = true

	# Seal arena bounds
	if _arena_bounds_body != null:
		_arena_bounds_body.set_collision_layer_value(1, true)

	# Find player for recorder if not provided
	if player_node == null and is_inside_tree():
		var tree := get_tree()
		if tree != null:
			player_node = tree.get_first_node_in_group("player") as Node2D
			if player_node == null:
				player_node = get_parent().get_node_or_null("../Player") as Node2D

	if _boss != null and player_node != null:
		var recorder: Node = _boss.get_node_or_null("RewindRecorder")
		if recorder != null:
			recorder.set("player", player_node)

	# Start battle
	if _hud != null and _hud.has_method("show_hud"):
		_hud.call("show_hud")
	if _boss != null and _boss.has_method("begin_battle"):
		_boss.call("begin_battle")

	boss_started.emit()


func _on_boss_defeated(boss_id: StringName) -> void:
	is_battle_active = false

	# Restore floor
	if _clock_floor != null and _clock_floor.has_method("restore_all"):
		_clock_floor.call("restore_all")

	# Remove all clock birds
	_despawn_all_clock_birds()

	# Unseal arena
	if _arena_bounds_body != null:
		_arena_bounds_body.set_collision_layer_value(1, false)

	# Hide purify supply
	if _purify_supply != null:
		_purify_supply.visible = false

	boss_defeated.emit(boss_id)


func _on_boss_phase_changed(new_phase: int) -> void:
	# HelionBoss.Phase.PURIFICATION_REQUIRED == 5
	if new_phase == 5:
		_activate_purify_supply()


func _activate_purify_supply() -> void:
	if _purify_supply == null:
		return
	_purify_supply.visible = true
	if _purify_supply is Area2D:
		(_purify_supply as Area2D).monitoring = true
	# Pulse visual
	var tween := create_tween()
	if tween != null:
		tween.set_loops()
		tween.tween_property(_purify_supply, "modulate:a", 0.5, 0.6)
		tween.tween_property(_purify_supply, "modulate:a", 1.0, 0.6)


func get_arena_rect() -> Rect2:
	var half_w: float = arena_width * 0.5
	return Rect2(
		global_position.x - half_w,
		global_position.y - arena_height,
		arena_width,
		arena_height
	)


func apply_damage_to_player(amount: int, source: StringName) -> void:
	# Walk up parent chain to find DayLevelEnvironment
	var p: Node = get_parent()
	while p != null:
		if p.has_method("apply_player_damage"):
			p.call("apply_player_damage", amount, source)
			return
		if p.has_method("apply_fall_or_hazard_damage"):
			p.call("apply_fall_or_hazard_damage", amount, String(source))
			return
		p = p.get_parent()


# ─── Clock Bird Management ───

func _process(delta: float) -> void:
	if not is_battle_active or _boss == null:
		return

	# Clean up dead birds
	_active_clock_birds = _active_clock_birds.filter(func(b: Node) -> bool:
		return is_instance_valid(b) and b.is_inside_tree()
	)

	# Spawn clock birds periodically in Phase 1 and 2
	var boss_phase: int = _boss.get("current_phase") if _boss != null else 0
	if boss_phase in [1, 2]:
		var max_birds: int = 2
		if _boss.get("config") != null:
			max_birds = _boss.get("config").max_clock_birds

		if _active_clock_birds.size() < max_birds:
			var spawn_interval: float = 8.0
			if _boss.get("config") != null:
				spawn_interval = _boss.get("config").clock_bird_spawn_interval
			_clock_bird_timer += delta
			if _clock_bird_timer >= spawn_interval:
				_clock_bird_timer = 0.0
				_spawn_clock_bird()


func _spawn_clock_bird() -> void:
	var bird_scene: PackedScene = load("res://day/levels/Aurem Clockyard/inside_systems/retro_clockbird.tscn") as PackedScene
	if bird_scene == null:
		return

	var bird: Node2D = bird_scene.instantiate() as Node2D
	if bird == null:
		return

	var side: float = -400.0 if randi() % 2 == 0 else 400.0
	bird.global_position = global_position + Vector2(side, -300)
	add_child(bird)
	_active_clock_birds.append(bird)


func _despawn_all_clock_birds() -> void:
	for bird: Node in _active_clock_birds:
		if is_instance_valid(bird):
			if bird.has_method("despawn"):
				bird.call("despawn")
			else:
				bird.queue_free()
	_active_clock_birds.clear()