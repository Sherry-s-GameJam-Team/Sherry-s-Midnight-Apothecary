extends SceneTree

func _initialize() -> void:
	var scene_resource := load("res://day/levels/golden_cliff/golden_cliff.tscn") as PackedScene
	if scene_resource == null:
		push_error("golden_cliff: failed to load scene")
		quit(1)
		return
	
	var level := scene_resource.instantiate()
	root.add_child(level)
	await process_frame
	
	var required_paths := [
		"EntryPoints/default",
		"EntryPoints/from_home",
		"EntryPoints/from_village",
		"Player",
		"Player/SherryCollision",
		"Player/SherryPresentation",
		"Player/Camera2D",
		"Player/PotionThrower",
		"WorldBounds",
		"Gameplay/BalanceMechanisms",
		"Gameplay/EntrancePortal",
		"Gameplay/VillagePortal",
		"Gameplay/ExitPortal",
		"LevelController"
	]
	
	for path in required_paths:
		if level.get_node_or_null(path) == null:
			push_error("golden_cliff: missing required node %s" % path)
			level.queue_free()
			quit(1)
			return
	var village_portal := level.get_node_or_null("Gameplay/VillagePortal") as DoorPortal
	if village_portal == null or village_portal.destination_level != &"golden_cliff_village" or village_portal.destination_entry_id != &"from_cliff":
		push_error("golden_cliff: VillagePortal must return to the village from_cliff entry point")
		level.queue_free()
		quit(1)
		return
	
	var mechanisms_parent := level.get_node("Gameplay/BalanceMechanisms")
	var break_a := level.get_node_or_null("Gameplay/Breakables/BreakA") as Node2D
	if break_a == null or break_a.z_index < 1 or break_a.position.y >= 0.0:
		push_error("golden_cliff: BreakA must begin above the camera without a position script")
		level.queue_free()
		quit(1)
		return
	if break_a.get_script() != null or break_a.get_node_or_null("Body/CollisionShape2D") == null or break_a.get_node_or_null("Sensor/CollisionShape2D") == null:
		push_error("golden_cliff: BreakA must retain its collision hierarchy without a behavior script")
		level.queue_free()
		quit(1)
		return
	var static_platforms := level.get_node_or_null("Gameplay/StaticPlatforms")
	for floor_name in [&"StartGround", &"GroundA", &"SlopeA", &"GroundB", &"GroundC", &"EndGround"]:
		var floor := static_platforms.get_node_or_null(NodePath(floor_name)) if static_platforms != null else null
		if floor == null or not floor.has_method("get_sway_offset"):
			push_error("golden_cliff: fixed floor '%s' is missing subtle horizontal sway" % floor_name)
			level.queue_free()
			quit(1)
			return
	var mech_children := mechanisms_parent.get_children()
	if mech_children.size() < 3:
		push_error("golden_cliff: expected at least 3 balance mechanisms, found %d" % mech_children.size())
		level.queue_free()
		quit(1)
		return
	
	var mechanism_ids := {}
	for mech in mech_children:
		var mid: StringName = mech.get("mechanism_id")
		if mid == &"":
			push_error("golden_cliff: mechanism missing mechanism_id")
			level.queue_free()
			quit(1)
			return
		if mechanism_ids.has(mid):
			push_error("golden_cliff: duplicate mechanism_id '%s'" % mid)
			level.queue_free()
			quit(1)
			return
		mechanism_ids[mid] = mech
		
		# Verify left and right pans exist or can receive hit
		if not mech.has_method("add_weight") or not mech.has_method("reset_balance"):
			push_error("golden_cliff: mechanism '%s' missing add_weight or reset_balance methods" % mid)
			level.queue_free()
			quit(1)
			return
	
	var expected_ids := [&"west_balance", &"middle_balance", &"east_balance"]
	for exp_id in expected_ids:
		if not mechanism_ids.has(exp_id):
			push_error("golden_cliff: missing expected mechanism '%s'" % exp_id)
			level.queue_free()
			quit(1)
			return
	
	# Test weight addition and reset on west_balance
	var west_mech = mechanism_ids[&"west_balance"]
	if not west_mech._balance_hint_text().contains("左盘 +2"):
		push_error("golden_cliff: west balance hint does not guide the player to add two left weights")
		level.queue_free()
		quit(1)
		return
	var boulder_a := level.get_node_or_null("Gameplay/FloatingBoulders/BoulderA")
	var boulder_b := level.get_node_or_null("Gameplay/FloatingBoulders/BoulderB")
	if boulder_a == null or boulder_b == null or not boulder_a.has_method("set_balance_height_offset") or not boulder_b.has_method("set_turbulent"):
		push_error("golden_cliff: western boulders are missing balance-control methods")
		level.queue_free()
		quit(1)
		return
	west_mech.add_weight(&"left")
	await create_timer(0.55).timeout
	if west_mech.left_weight != 1:
		push_error("golden_cliff: add_weight('left') failed to increase left_weight")
		level.queue_free()
		quit(1)
		return
	var start_ground := level.get_node_or_null("Gameplay/StaticPlatforms/StartGround") as StaticBody2D
	if start_ground == null or not is_equal_approx(start_ground.rotation, deg_to_rad(19.5)):
		push_error("golden_cliff: StartGround must move from 39 to 19.5 degrees after one left weight")
		level.queue_free()
		quit(1)
		return
	if not bool(boulder_a.get("_current_turbulence_multiplier") > 1.0) or not bool(boulder_a.get("_current_height_offset") < -600.0) or not bool(boulder_b.get("_current_height_offset") > 400.0):
		push_error("golden_cliff: western imbalance did not raise BoulderA, lower BoulderB, and increase turbulence")
		level.queue_free()
		quit(1)
		return
	
	west_mech.add_weight(&"right")
	if west_mech.right_weight != 3:
		push_error("golden_cliff: add_weight('right') failed to increase right_weight")
		level.queue_free()
		quit(1)
		return
	
	west_mech.reset_balance()
	if west_mech.left_weight != 0 or west_mech.right_weight != 2:
		push_error("golden_cliff: reset_balance() failed to restore initial weights")
		level.queue_free()
		quit(1)
		return
	await create_timer(0.55).timeout
	
	# Test controller logic: single mechanism stabilized should not activate portal
	var controller := level.get_node("LevelController")
	var portal := level.get_node("Gameplay/ExitPortal") as Area2D
	start_ground = level.get_node_or_null("Gameplay/StaticPlatforms/StartGround") as StaticBody2D
	if start_ground == null or not is_equal_approx(start_ground.rotation, deg_to_rad(39.0)):
		push_error("golden_cliff: StartGround must start tilted clockwise at 39 degrees")
		level.queue_free()
		quit(1)
		return
	var ground_b := level.get_node_or_null("Gameplay/StaticPlatforms/GroundB") as StaticBody2D
	if ground_b == null or not is_equal_approx(ground_b.rotation, deg_to_rad(30.0)):
		push_error("golden_cliff: GroundB must start tilted clockwise at 30 degrees")
		level.queue_free()
		quit(1)
		return
	
	controller._connect_mechanisms()
	
	# West alone stabilized
	west_mech._stabilize()
	if controller.balance_states.get(&"west_balance") != true:
		push_error("golden_cliff: controller did not record west_balance stabilization")
		level.queue_free()
		quit(1)
		return
	await create_timer(1.3).timeout
	if not is_zero_approx(start_ground.rotation):
		push_error("golden_cliff: west balance stabilization did not level StartGround")
		level.queue_free()
		quit(1)
		return
	
	if portal.monitoring or portal.monitorable:
		push_error("golden_cliff: portal became active prematurely after single mechanism stabilization")
		level.queue_free()
		quit(1)
		return
	
	# Stabilize middle and east
	var middle_mech = mechanism_ids[&"middle_balance"]
	var east_mech = mechanism_ids[&"east_balance"]
	middle_mech._stabilize()
	await create_timer(1.3).timeout
	if not is_zero_approx(ground_b.rotation):
		push_error("golden_cliff: middle balance stabilization did not level GroundB")
		level.queue_free()
		quit(1)
		return
	east_mech._stabilize()
	await create_timer(1.1).timeout
	if break_a.position.distance_to(controller.break_a_resolved_position) > 1.0:
		push_error("golden_cliff: BalanceC did not move BreakA to its resolved position")
		level.queue_free()
		quit(1)
		return
	
	if not controller._disaster_cleared:
		push_error("golden_cliff: controller failed to clear disaster when all 3 mechanisms stabilized")
		level.queue_free()
		quit(1)
		return
	
	level.queue_free()
	print("golden_cliff smoke test: PASS")
	quit(0)
