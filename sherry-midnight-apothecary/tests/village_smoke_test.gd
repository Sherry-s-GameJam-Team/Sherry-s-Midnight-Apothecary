extends SceneTree

func _initialize() -> void:
	var level_data := load("res://day/levels/golden_cliff/village/village_level.tres")
	if level_data == null or level_data.id != &"golden_cliff_village":
		push_error("village_smoke_test: Failed to load or validate village_level.tres")
		quit(1)
		return
	
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
	
	var one_way := world_bounds.get_node_or_null("OneWayPlatforms") as StaticBody2D
	if one_way == null:
		push_error("village_smoke_test: Missing OneWayPlatforms node under CS/WorldBounds")
		quit(1)
		return
	
	if one_way.collision_layer != 2:
		push_error("village_smoke_test: OneWayPlatforms collision_layer must be 2. Found: %d" % one_way.collision_layer)
		quit(1)
		return
	
	if camera.limit_left != -1118 or camera.limit_top != -1389 or camera.limit_right != 8550 or camera.limit_bottom != 803:
		push_error("village_smoke_test: Camera limits not set to (-1118, -1389) -> (8550, 803). Found: (%d, %d, %d, %d)" % [camera.limit_left, camera.limit_top, camera.limit_right, camera.limit_bottom])
		quit(1)
		return

	# Verify the village exit is the shared DoorPortal route matching Magic Map
	# Anchor03, which is authored as the Golden Cliff destination.
	var exit_portal := inst.get_node_or_null("ExitPortal") as DoorPortal
	if exit_portal == null:
		push_error("village_smoke_test: Missing ExitPortal DoorPortal")
		quit(1)
		return
	if exit_portal.destination_level != &"golden_cliff" or exit_portal.destination_entry_id != &"from_village":
		push_error("village_smoke_test: ExitPortal must route to the Golden Cliff from_village entry point")
		quit(1)
		return
	var interaction_scene := load("res://day/interactables/map_switch/map_switch_interaction.tscn") as PackedScene
	var interaction := interaction_scene.instantiate() if interaction_scene != null else null
	var anchor03 := interaction.get_node_or_null("MapViewport/MagicMapCanvas/Map/AnchorPoints/Anchor03") as MapSwitchAnchor if interaction != null else null
	if anchor03 == null or anchor03.destination_id != exit_portal.destination_level:
		push_error("village_smoke_test: ExitPortal destination must match MapSwitchInteraction Anchor03")
		quit(1)
		return
	interaction.free()
	var exit_portal_visual := exit_portal.get_node_or_null("Visual") as Sprite2D
	if exit_portal_visual == null or exit_portal_visual.texture == null or exit_portal_visual.texture.resource_path != "res://day/levels/golden_cliff/art/cliff_yellow_gate_wayportal_01.png":
		push_error("village_smoke_test: ExitPortal must use the inactive wayportal texture")
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
