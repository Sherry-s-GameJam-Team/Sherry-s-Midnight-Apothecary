extends Node

@export_range(1, 8, 1) var required_balance_count: int = 3
@export var break_a_resolved_position := Vector2(4509, 743)

@onready var level_root: Node = get_parent()
@onready var mechanisms: Node = get_parent().get_node_or_null("Gameplay/BalanceMechanisms") if get_parent() != null else null
@onready var portal: Area2D = get_parent().get_node_or_null("Gameplay/ExitPortal") as Area2D if get_parent() != null else null
@onready var portal_collision: CollisionShape2D = get_parent().get_node_or_null("Gameplay/ExitPortal/CollisionShape2D") as CollisionShape2D if get_parent() != null else null
@onready var broken_visual: Sprite2D = get_parent().get_node_or_null("Gameplay/ExitPortal/PortalBroken") as Sprite2D if get_parent() != null else null
@onready var repaired_visual: Sprite2D = get_parent().get_node_or_null("Gameplay/ExitPortal/PortalRepaired") as Sprite2D if get_parent() != null else null
@onready var breakables: Node = get_parent().get_node_or_null("Gameplay/Breakables") if get_parent() != null else null
@onready var floating_boulders: Node = get_parent().get_node_or_null("Gameplay/FloatingBoulders") if get_parent() != null else null
@onready var static_platforms: Node = get_parent().get_node_or_null("Gameplay/StaticPlatforms") if get_parent() != null else null

var balance_states: Dictionary = {
	&"west_balance": false,
	&"middle_balance": false,
	&"east_balance": false
}

var _disaster_cleared := false
var _break_a_revealed := false
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_ensure_references()
	_connect_mechanisms()
	# BalanceMechanism initializes its exported starting weights in _ready().
	# This controller is an earlier sibling, so synchronize after all scene
	# children have finished their own initialization.
	call_deferred("_sync_initial_west_balance_state")
	if level_root != null and level_root.has_signal("environment_state_changed"):
		if not level_root.environment_state_changed.is_connected(_on_environment_state_changed):
			level_root.environment_state_changed.connect(_on_environment_state_changed)
	
	_set_portal_active(false)
	# DoorPortal initializes after this sibling in the scene tree and enables its
	# own monitoring, so lock the exit once more after all child _ready calls.
	call_deferred("_set_portal_active", false)
	_apply_environment_state()

func _ensure_references() -> void:
	if level_root == null:
		level_root = get_parent()
	if level_root != null:
		if mechanisms == null:
			mechanisms = level_root.get_node_or_null("Gameplay/BalanceMechanisms")
		if portal == null:
			portal = level_root.get_node_or_null("Gameplay/ExitPortal") as Area2D
		if portal_collision == null:
			portal_collision = level_root.get_node_or_null("Gameplay/ExitPortal/CollisionShape2D") as CollisionShape2D
		if broken_visual == null:
			broken_visual = level_root.get_node_or_null("Gameplay/ExitPortal/PortalBroken") as Sprite2D
		if repaired_visual == null:
			repaired_visual = level_root.get_node_or_null("Gameplay/ExitPortal/PortalRepaired") as Sprite2D
		if breakables == null:
			breakables = level_root.get_node_or_null("Gameplay/Breakables")
		if floating_boulders == null:
			floating_boulders = level_root.get_node_or_null("Gameplay/FloatingBoulders")
		if static_platforms == null:
			static_platforms = level_root.get_node_or_null("Gameplay/StaticPlatforms")

func _connect_mechanisms() -> void:
	_ensure_references()
	if mechanisms != null:
		for mechanism in mechanisms.get_children():
			if mechanism.has_signal("stabilized"):
				if not mechanism.stabilized.is_connected(_on_mechanism_stabilized):
					mechanism.stabilized.connect(_on_mechanism_stabilized)
			if mechanism.has_signal("weight_changed"):
				var weight_changed_callback := _on_mechanism_weight_changed.bind(mechanism)
				if not mechanism.weight_changed.is_connected(weight_changed_callback):
					mechanism.weight_changed.connect(weight_changed_callback)
			if mechanism.has_signal("balance_reset"):
				var reset_callback := _on_mechanism_balance_reset.bind(mechanism)
				if not mechanism.balance_reset.is_connected(reset_callback):
					mechanism.balance_reset.connect(reset_callback)

func _sync_initial_west_balance_state() -> void:
	_ensure_references()
	if mechanisms == null:
		return
	var west_balance := mechanisms.get_node_or_null("BalanceA")
	if west_balance != null:
		_sync_west_balance_boulders(west_balance)

func _on_mechanism_weight_changed(_side: StringName, _new_weight: int, mechanism: Node) -> void:
	if mechanism.get("mechanism_id") == &"west_balance":
		_sync_west_balance_boulders(mechanism)

func _on_mechanism_balance_reset(mechanism: Node) -> void:
	if mechanism.get("mechanism_id") == &"west_balance":
		_sync_west_balance_boulders(mechanism)

func _sync_west_balance_boulders(mechanism: Node) -> void:
	var is_stabilized := bool(mechanism.get("is_stabilized"))
	var is_imbalanced := int(mechanism.get("left_weight")) != int(mechanism.get("right_weight"))
	if floating_boulders != null:
		for node_name in [&"BoulderA", &"BoulderB"]:
			var boulder := floating_boulders.get_node_or_null(NodePath(node_name))
			if boulder == null:
				continue
			if boulder.has_method("set_stable"):
				boulder.call("set_stable", is_stabilized)
			if boulder.has_method("set_turbulent"):
				boulder.call("set_turbulent", is_imbalanced and not is_stabilized)
			if boulder.has_method("set_balance_height_offset"):
				var height_offset := -750.0 if node_name == &"BoulderA" and is_imbalanced else (500.0 if is_imbalanced else 0.0)
				boulder.call("set_balance_height_offset", height_offset)
	_sync_west_balance_start_ground(mechanism, is_stabilized)

func _sync_west_balance_start_ground(mechanism: Node, is_stabilized: bool) -> void:
	if static_platforms == null:
		return
	var start_ground := static_platforms.get_node_or_null("StartGround") as StaticBody2D
	if start_ground == null:
		return
	var weight_difference := int(mechanism.get("right_weight")) - int(mechanism.get("left_weight"))
	var target_rotation := 0.0 if is_stabilized else deg_to_rad(clampf(float(weight_difference) * 19.5, -39.0, 39.0))
	var ground_tween := start_ground.create_tween()
	ground_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	ground_tween.tween_property(start_ground, "rotation", target_rotation, 0.45)

func _on_mechanism_stabilized(mechanism_id: StringName) -> void:
	balance_states[mechanism_id] = true
	_apply_mechanism_terrain_effect(mechanism_id)
	
	var all_stabilized := true
	for state_val: bool in balance_states.values():
		if not state_val:
			all_stabilized = false
			break
	
	if all_stabilized and not _disaster_cleared:
		_resolve_disaster()

func _on_balance_c_stabilized(_mechanism_id: StringName) -> void:
	_reveal_break_a()

func _on_balance_c_weight_changed(_side: StringName, _new_weight: int) -> void:
	if level_root == null:
		return
	var balance_c := level_root.get_node_or_null("Gameplay/BalanceMechanisms/BalanceC")
	if balance_c != null and balance_c.left_weight == balance_c.target_left_weight and balance_c.right_weight == balance_c.target_right_weight:
		_reveal_break_a()

func _reveal_break_a() -> void:
	if _break_a_revealed or level_root == null:
		return
	var break_a := level_root.get_node_or_null("Gameplay/Breakables/BreakA") as Node2D
	if break_a == null:
		return
	_break_a_revealed = true
	var break_a_tween := break_a.create_tween()
	break_a_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	break_a_tween.tween_property(break_a, "position", break_a_resolved_position, 1.0)

func _apply_mechanism_terrain_effect(mechanism_id: StringName) -> void:
	_ensure_references()
	match mechanism_id:
		&"west_balance":
			# The western scale settles the A/B crossing and its tilted approach.
			if mechanisms != null:
				var west_balance := mechanisms.get_node_or_null("BalanceA")
				if west_balance != null:
					_sync_west_balance_boulders(west_balance)
		
		&"middle_balance":
			# Restore the middle bridge and its sloped landing to horizontal.
			if static_platforms != null:
				for platform_name in [&"SlopeA", &"GroundB"]:
					var platform := static_platforms.get_node_or_null(NodePath(platform_name)) as StaticBody2D
					if platform != null:
						var bridge_tween := platform.create_tween()
						bridge_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
						bridge_tween.tween_property(platform, "rotation", 0.0, 1.2)
		
		&"east_balance":
			# Fallback for programmatic stabilization; the scene also directly
			# connects BalanceC's stabilized signal to _on_balance_c_stabilized().
			_reveal_break_a()

			# Lower the eastern floating platform towards reachable height.
			if floating_boulders != null:
				for node_name in ["BoulderC", "BoulderD"]:
					if floating_boulders.has_node(node_name):
						var boulder: Node = floating_boulders.get_node(node_name)
						if boulder.has_method("set_stable"):
							boulder.call("set_stable", true)
				if floating_boulders.has_node("ExitPlatform"):
					var exit_plat: Node2D = floating_boulders.get_node("ExitPlatform") as Node2D
					if exit_plat != null:
						var plat_tween := exit_plat.create_tween()
						if plat_tween != null:
							plat_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
							plat_tween.tween_property(exit_plat, "position:y", exit_plat.position.y + 110.0, 1.5)

func _resolve_disaster() -> void:
	_disaster_cleared = true
	_ensure_references()
	if level_root != null and level_root.has_method("set_corrupted"):
		level_root.set_corrupted(false)
	
	_play_portal_restoration_sequence()

func _set_portal_active(active: bool) -> void:
	_ensure_references()
	if portal != null:
		portal.set_deferred("monitoring", active)
		portal.set_deferred("monitorable", active)
	if portal_collision != null:
		portal_collision.set_deferred("disabled", not active)
	if broken_visual != null:
		broken_visual.visible = not active
	if repaired_visual != null:
		repaired_visual.visible = active

func _on_environment_state_changed(_corrupted: bool) -> void:
	_apply_environment_state()

func _apply_environment_state() -> void:
	_ensure_references()
	var corrupted := true
	if level_root != null and level_root.has_method("is_corrupted"):
		corrupted = level_root.is_corrupted()
	if breakables != null:
		for platform in breakables.get_children():
			if platform.has_method("set_enabled"):
				platform.set_enabled(corrupted)
	if not corrupted:
		_set_portal_active(true)

func _play_portal_restoration_sequence() -> void:
	_ensure_references()
	if portal == null or level_root == null:
		_set_portal_active(true)
		return
	
	var center := portal.global_position
	
	# 1. Gate slight vibration
	var gate_shake := portal.create_tween()
	if gate_shake != null:
		gate_shake.tween_property(portal, "position:x", portal.position.x + 4.0, 0.05)
		gate_shake.tween_property(portal, "position:x", portal.position.x - 4.0, 0.05)
		gate_shake.tween_property(portal, "position:x", portal.position.x + 2.0, 0.05)
		gate_shake.tween_property(portal, "position:x", portal.position.x, 0.05)
	
	# 2. Three balance stone light orbs converging to portal socket
	for i in range(3):
		var orb := Polygon2D.new()
		var s := 9.0
		orb.polygon = PackedVector2Array([
			Vector2(0, -s), Vector2(s, 0), Vector2(0, s), Vector2(-s, 0)
		])
		orb.color = Color(1.0, 0.88, 0.35, 0.95)
		orb.z_index = 62
		level_root.add_child(orb)
		
		var start_pos := center + Vector2(cos(TAU * float(i) / 3.0) * 220.0, sin(TAU * float(i) / 3.0) * 160.0 - 40.0)
		orb.global_position = start_pos
		
		var orb_tween := orb.create_tween()
		if orb_tween != null:
			orb_tween.set_parallel(false)
			orb_tween.tween_property(orb, "global_position", center + Vector2(0, 70), 1.2 + i * 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
			orb_tween.tween_callback(orb.queue_free)
		else:
			orb.queue_free()
	
	# 3. Rotating energy rings
	for ring_index in range(3):
		var ring := Line2D.new()
		ring.width = 6.0 - float(ring_index)
		ring.default_color = Color(1.0, 0.88, 0.32, 0.9)
		ring.closed = true
		ring.z_index = 60
		var points := PackedVector2Array()
		for index in range(41):
			var angle := TAU * float(index) / 40.0
			points.append(Vector2(cos(angle), sin(angle)) * (85.0 + ring_index * 32.0))
		ring.points = points
		level_root.add_child(ring)
		ring.global_position = center + Vector2(0, 80)
		ring.scale = Vector2(0.2, 0.2)
		
		var tween := ring.create_tween()
		if tween != null:
			tween.set_parallel(true)
			tween.tween_property(ring, "scale", Vector2(1.8, 1.8), 1.4 + ring_index * 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(ring, "rotation", TAU * 0.75, 1.4 + ring_index * 0.2)
			tween.tween_property(ring, "modulate:a", 0.0, 1.4 + ring_index * 0.2)
			tween.finished.connect(ring.queue_free)
		else:
			ring.queue_free()
	
	# 4. Inner portal energy fill
	var energy_fill := Polygon2D.new()
	var ep_points := PackedVector2Array()
	for index in range(32):
		var angle := TAU * float(index) / 32.0
		ep_points.append(Vector2(cos(angle) * 75.0, sin(angle) * 115.0))
	energy_fill.polygon = ep_points
	energy_fill.color = Color(1.0, 0.85, 0.25, 0.0)
	energy_fill.z_index = 55
	level_root.add_child(energy_fill)
	energy_fill.global_position = center + Vector2(0, 80)
	
	var fill_tween := energy_fill.create_tween()
	if fill_tween != null:
		fill_tween.tween_property(energy_fill, "color:a", 0.45, 1.2)
		fill_tween.tween_property(energy_fill, "color:a", 0.0, 0.8)
		fill_tween.finished.connect(energy_fill.queue_free)
	else:
		energy_fill.queue_free()
	
	# 5. Upward golden sparks
	for index in range(24):
		var spark := Polygon2D.new()
		var s := _rng.randf_range(3.0, 7.0)
		spark.polygon = PackedVector2Array([Vector2(0, -s), Vector2(s, 0), Vector2(0, s), Vector2(-s, 0)])
		spark.color = Color(1.0, 0.82, 0.20, 0.95)
		spark.z_index = 61
		level_root.add_child(spark)
		spark.global_position = center + Vector2(_rng.randf_range(-60, 60), _rng.randf_range(30, 120))
		
		var target := spark.global_position + Vector2(_rng.randf_range(-40.0, 40.0), _rng.randf_range(-140.0, -260.0))
		var tween := spark.create_tween()
		if tween != null:
			tween.set_parallel(true)
			tween.tween_property(spark, "global_position", target, 1.8 + _rng.randf_range(0.0, 0.6))
			tween.tween_property(spark, "modulate:a", 0.0, 1.8 + _rng.randf_range(0.0, 0.6))
			tween.finished.connect(spark.queue_free)
		else:
			spark.queue_free()
	
	# Unlock portal after 2.2 seconds
	if is_inside_tree():
		var tree := get_tree()
		if tree != null:
			var unlock_timer := tree.create_timer(2.2)
			await unlock_timer.timeout
	_set_portal_active(true)
