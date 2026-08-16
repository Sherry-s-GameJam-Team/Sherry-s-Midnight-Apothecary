extends Node

@export_range(1, 8, 1) var required_balance_count: int = 3

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
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_ensure_references()
	_connect_mechanisms()
	if level_root != null and level_root.has_signal("environment_state_changed"):
		if not level_root.environment_state_changed.is_connected(_on_environment_state_changed):
			level_root.environment_state_changed.connect(_on_environment_state_changed)
	
	_set_portal_active(false)
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

func _apply_mechanism_terrain_effect(mechanism_id: StringName) -> void:
	_ensure_references()
	match mechanism_id:
		&"west_balance":
			# Stabilize western floating boulders A and B
			if floating_boulders != null:
				for node_name in ["BoulderA", "BoulderB"]:
					if floating_boulders.has_node(node_name):
						var boulder: Node = floating_boulders.get_node(node_name)
						if boulder.has_method("set_stable"):
							boulder.call("set_stable", true)
		
		&"middle_balance":
			# Restore tilted stone bridge / slope to horizontal
			if static_platforms != null and static_platforms.has_node("SlopeA"):
				var slope: StaticBody2D = static_platforms.get_node("SlopeA") as StaticBody2D
				if slope != null:
					var bridge_tween := slope.create_tween()
					if bridge_tween != null:
						bridge_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
						bridge_tween.tween_property(slope, "rotation", 0.0, 1.2)
		
		&"east_balance":
			# Lower the eastern floating platform towards reachable height
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
	var tree := get_tree()
	if tree != null:
		var unlock_timer := tree.create_timer(2.2)
		await unlock_timer.timeout
	_set_portal_active(true)
