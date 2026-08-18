extends SceneTree

func _initialize() -> void:
	var scene_resource := load("res://day/levels/golden_cliff/golden_cliff.tscn") as PackedScene
	if scene_resource == null:
		push_error("golden_cliff: failed to load scene")
		quit(1)
		return
	
	var level := scene_resource.instantiate()
	root.add_child(level)
	
	var required_paths := [
		"EntryPoints/default",
		"EntryPoints/from_home",
		"Player",
		"Player/SherryCollision",
		"Player/SherryPresentation",
		"Player/Camera2D",
		"Player/PotionThrower",
		"WorldBounds",
		"Gameplay/BalanceMechanisms",
		"Gameplay/EntrancePortal",
		"Gameplay/ExitPortal",
		"LevelController"
	]
	
	for path in required_paths:
		if level.get_node_or_null(path) == null:
			push_error("golden_cliff: missing required node %s" % path)
			level.queue_free()
			quit(1)
			return
	
	var mechanisms_parent := level.get_node("Gameplay/BalanceMechanisms")
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
	west_mech.add_weight(&"left")
	if west_mech.left_weight != 1:
		push_error("golden_cliff: add_weight('left') failed to increase left_weight")
		level.queue_free()
		quit(1)
		return
	
	west_mech.add_weight(&"right")
	if west_mech.right_weight != 1:
		push_error("golden_cliff: add_weight('right') failed to increase right_weight")
		level.queue_free()
		quit(1)
		return
	
	west_mech.reset_balance()
	if west_mech.left_weight != 0 or west_mech.right_weight != 0:
		push_error("golden_cliff: reset_balance() failed to restore initial weights")
		level.queue_free()
		quit(1)
		return
	
	# Test controller logic: single mechanism stabilized should not activate portal
	var controller := level.get_node("LevelController")
	var portal := level.get_node("Gameplay/ExitPortal") as Area2D
	
	controller._connect_mechanisms()
	
	# West alone stabilized
	west_mech._stabilize()
	if controller.balance_states.get(&"west_balance") != true:
		push_error("golden_cliff: controller did not record west_balance stabilization")
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
	east_mech._stabilize()
	
	if not controller._disaster_cleared:
		push_error("golden_cliff: controller failed to clear disaster when all 3 mechanisms stabilized")
		level.queue_free()
		quit(1)
		return
	
	level.queue_free()
	print("golden_cliff smoke test: PASS")
	quit(0)
