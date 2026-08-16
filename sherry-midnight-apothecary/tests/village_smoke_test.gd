extends SceneTree

func _initialize() -> void:
	var scene := load("res://day/levels/golden_cliff/village/village.tscn") as PackedScene
	if scene == null:
		push_error("village_smoke_test: Failed to load village.tscn")
		quit(1)
		return
	
	var inst: Node = scene.instantiate()
	if inst == null:
		push_error("village_smoke_test: Failed to instantiate village.tscn")
		quit(1)
		return
	
	root.add_child(inst)
	
	# Verify Parallax Layers
	var fs := inst.get_node_or_null("FS") as Parallax2D
	var ms := inst.get_node_or_null("MS") as Parallax2D
	var cs := inst.get_node_or_null("CS") as Parallax2D
	
	if fs == null or ms == null or cs == null:
		push_error("village_smoke_test: Missing one or more parallax layers (FS, MS, CS)")
		quit(1)
		return
	
	if fs.scroll_scale.x >= ms.scroll_scale.x or ms.scroll_scale.x >= cs.scroll_scale.x:
		push_error("village_smoke_test: Parallax layer scroll scales not ordered correctly (FS < MS < CS)")
		quit(1)
		return
	
	# Verify Player and Sub-nodes
	var player := inst.get_node_or_null("Player")
	if player == null:
		push_error("village_smoke_test: Missing Player node")
		quit(1)
		return
	
	if player.get_node_or_null("SherryCollision") == null:
		push_error("village_smoke_test: Missing SherryCollision")
		quit(1)
		return
	
	if player.get_node_or_null("SherryPresentation") == null:
		push_error("village_smoke_test: Missing SherryPresentation")
		quit(1)
		return
	
	if player.get_node_or_null("PotionThrower") == null:
		push_error("village_smoke_test: Missing PotionThrower")
		quit(1)
		return
	
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		push_error("village_smoke_test: Missing Camera2D")
		quit(1)
		return
	
	# Verify Camera Bounds and WorldBounds under CS
	var world_bounds := inst.get_node_or_null("CS/WorldBounds")
	if world_bounds == null:
		push_error("village_smoke_test: WorldBounds is not a child of CS")
		quit(1)
		return
	
	if camera.limit_left != -1118 or camera.limit_top != -1389 or camera.limit_right != 6977 or camera.limit_bottom != 803:
		push_error("village_smoke_test: Camera limits not set to (-1118, -1389) -> (6977, 803). Found: (%d, %d, %d, %d)" % [camera.limit_left, camera.limit_top, camera.limit_right, camera.limit_bottom])
		quit(1)
		return
	
	# Verify DeveloperConsole
	var debug_ui := inst.get_node_or_null("DebugUI") as CanvasLayer
	if debug_ui == null or debug_ui.get_node_or_null("DeveloperConsole") == null:
		push_error("village_smoke_test: Missing DebugUI/DeveloperConsole")
		quit(1)
		return
	
	# Verify PauseMenu UI System
	var pause_layer := inst.get_node_or_null("PauseMenuLayer") as CanvasLayer
	if pause_layer == null or pause_layer.get_node_or_null("PauseMenu") == null:
		push_error("village_smoke_test: Missing PauseMenuLayer/PauseMenu")
		quit(1)
		return
	
	print("VILLAGE_SMOKE_TEST_OK")
	inst.queue_free()
	quit(0)
