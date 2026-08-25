extends SceneTree

var failures: Array[String] = []
var warnings: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _fail(msg: String) -> void:
	failures.append(msg)
	push_error("[AUDIT FAIL] " + msg)

func _warn(msg: String) -> void:
	warnings.append(msg)
	print("[AUDIT WARN] " + msg)

func _log(msg: String) -> void:
	print("[AUDIT INFO] " + msg)

func _run() -> void:
	_log("Starting comprehensive level & transition audit...")

	# --- PART 1: UID Duplication Scan ---
	_audit_uids()
	_log("UID audit finished. Failures so far: %d" % failures.size())

	# --- PART 2: DayRuntime LEVELS and EntryPoint / Camera / Fade Checks ---
	await _audit_levels_and_portals()
	_log("Level & portal audit finished. Total failures: %d" % failures.size())

	_finish()

func _audit_uids() -> void:
	_log("--- Scanning all scenes and resources for duplicate file UIDs ---")
	var uid_to_path: Dictionary = {}
	var files: Array[String] = []
	_collect_files_recursive("res://", files)
	
	for file_path in files:
		if not file_path.ends_with(".tscn") and not file_path.ends_with(".tres") and not file_path.ends_with(".dialogue"):
			continue
		var f := FileAccess.open(file_path, FileAccess.READ)
		if f == null:
			continue
		var header := f.get_line()
		if (header.begins_with("[gd_scene") or header.begins_with("[gd_resource") or header.begins_with("[resource")) and header.contains("uid=\""):
			var start_idx := header.find("uid=\"") + 5
			var end_idx := header.find("\"", start_idx)
			if start_idx >= 5 and end_idx > start_idx:
				var uid_str := header.substr(start_idx, end_idx - start_idx)
				if uid_to_path.has(uid_str):
					_fail("Duplicate root UID '%s' found between:\n    1) '%s'\n    2) '%s'" % [uid_str, uid_to_path[uid_str], file_path])
				else:
					uid_to_path[uid_str] = file_path

func _collect_files_recursive(dir_path: String, out_files: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.begins_with(".") or file_name == "addons" or file_name == ".godot":
			file_name = dir.get_next()
			continue
		var full_path := dir_path.path_join(file_name)
		if dir.current_is_dir():
			_collect_files_recursive(full_path, out_files)
		else:
			out_files.append(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()

func _audit_levels_and_portals() -> void:
	_log("--- Auditing DayRuntime.LEVELS, Cameras, Portals, and EntryPoints ---")
	
	var level_data_map: Dictionary = {} # level_id (StringName) -> LevelData
	var level_instance_map: Dictionary = {} # level_id (StringName) -> Node
	var level_entry_points: Dictionary = {} # level_id (StringName) -> Array[StringName]
	var all_portals: Array[Dictionary] = [] # list of { source_level_id, portal_node, dest_level, dest_entry, fallback }

	for level_data in DayRuntime.LEVELS:
		if level_data == null:
			_fail("Found null entry in DayRuntime.LEVELS")
			continue
		
		var level_id := level_data.id
		if level_id == &"":
			_fail("LevelData at %s has empty id" % level_data.resource_path)
			continue
		
		if level_data_map.has(level_id):
			_fail("Duplicate level id '%s' registered in DayRuntime.LEVELS: %s vs %s" % [
				level_id, level_data.resource_path, level_data_map[level_id].resource_path
			])
		level_data_map[level_id] = level_data

		if level_data.content_scene == null:
			_fail("LevelData '%s' (%s) has no content_scene" % [level_id, level_data.resource_path])
			continue
		
		# Instantiate scene to inspect
		var instance: Node = null
		var err = null
		instance = level_data.content_scene.instantiate()
		if instance == null:
			_fail("Level '%s' content_scene failed to instantiate: %s" % [level_id, level_data.content_scene.resource_path])
			continue
		
		root.add_child(instance)
		await process_frame

		level_instance_map[level_id] = instance
		var entries: Array[StringName] = []

		# Check EntryPoints
		var entry_points_node := instance.get_node_or_null("EntryPoints")
		if entry_points_node == null:
			_fail("Level '%s' (%s) is missing 'EntryPoints' root node" % [level_id, instance.name])
		else:
			for child in entry_points_node.get_children():
				if child is Marker2D:
					entries.append(StringName(child.name))
			
			if not entries.has(&"default"):
				_fail("Level '%s' EntryPoints is missing 'default' Marker2D" % level_id)
			if level_data.default_entry_id != &"" and not entries.has(level_data.default_entry_id):
				_fail("Level '%s' default_entry_id '%s' not found in EntryPoints" % [level_id, level_data.default_entry_id])

		level_entry_points[level_id] = entries

		# Check Player and Camera2D
		var player := instance.get_node_or_null("Player") as Node2D
		if player == null:
			# Some minigames/puzzle levels might handle player differently, check
			_warn("Level '%s' has no root 'Player' node (might be standalone minigame/controller)" % level_id)
		else:
			var cam := player.get_node_or_null("Camera2D") as Camera2D
			if cam == null:
				_warn("Level '%s' Player has no Camera2D child" % level_id)
			else:
				if cam.limit_left >= cam.limit_right and cam.limit_right != 10000000:
					_fail("Level '%s' Camera2D has invalid horizontal limits: left=%d, right=%d" % [level_id, cam.limit_left, cam.limit_right])
				if cam.limit_top >= cam.limit_bottom and cam.limit_bottom != 10000000:
					_fail("Level '%s' Camera2D has invalid vertical limits: top=%d, bottom=%d" % [level_id, cam.limit_top, cam.limit_bottom])

		# Check for stuck CanvasLayers / FadeRects
		for fade_node in instance.find_children("*", "ColorRect", true, false):
			var color_rect := fade_node as ColorRect
			if color_rect.name in ["FadeRect", "Blackout", "Fade"] and color_rect.is_visible_in_tree() and color_rect.modulate.a >= 0.99 and color_rect.color.a >= 0.99:
				_fail("Level '%s' has ColorRect '%s' that is fully opaque and visible on scene load (will cause blackout/grey screen)" % [level_id, color_rect.get_path()])

		# Collect all DoorPortals
		for node in instance.find_children("*", "DoorPortal", true, false):
			var portal := node as DoorPortal
			all_portals.append({
				"source_level_id": level_id,
				"portal_node": portal,
				"destination_level": portal.destination_level,
				"destination_entry_id": portal.destination_entry_id,
				"use_active_home_destination": portal.use_active_home_destination,
				"fallback_scene_path": portal.fallback_scene_path,
				"path": portal.get_path()
			})

		# Also check any custom exit areas (e.g. ExitToCrown, etc.)
		for exit_node in instance.find_children("*Exit*", "Area2D", true, false):
			if not (exit_node is DoorPortal):
				_log("Found custom exit Area2D: %s in level %s" % [exit_node.get_path(), level_id])

		instance.queue_free()
		await process_frame

	_log("Audited %d registered levels." % level_data_map.size())

	# --- PART 3: DoorPortal Target Validation ---
	_log("--- Validating %d DoorPortals across all levels ---" % all_portals.size())
	for p in all_portals:
		var source_id: StringName = p["source_level_id"]
		var dest_id: StringName = p["destination_level"]
		var dest_entry: StringName = p["destination_entry_id"]
		var use_home: bool = p["use_active_home_destination"]
		var fallback: String = p["fallback_scene_path"]
		var node_path: NodePath = p["path"]

		if use_home:
			_log("Portal at %s uses dynamic active_home_destination (OK)" % node_path)
			continue

		if dest_id == &"":
			_fail("DoorPortal at %s has empty destination_level" % node_path)
			continue

		if not level_data_map.has(dest_id):
			_fail("DoorPortal in level '%s' at %s targets unregistered level '%s'" % [source_id, node_path, dest_id])
			continue

		# Check target entry point
		var target_entries: Array[StringName] = level_entry_points.get(dest_id, [])
		if dest_entry != &"" and not target_entries.has(dest_entry):
			_fail("DoorPortal in level '%s' at %s targets non-existent entry '%s' in level '%s' (available: %s)" % [
				source_id, node_path, dest_entry, dest_id, str(target_entries)
			])

		# Check fallback path
		if not fallback.is_empty() and not FileAccess.file_exists(fallback):
			_fail("DoorPortal at %s has missing fallback_scene_path: '%s'" % [node_path, fallback])

func _finish() -> void:
	print("\n==============================================")
	print("AUDIT RESULTS SUMMARY:")
	print("Failures: %d" % failures.size())
	print("Warnings: %d" % warnings.size())
	print("==============================================")

	if not warnings.is_empty():
		print("\n--- WARNINGS ---")
		for w in warnings:
			print("  [WARN] ", w)

	if not failures.is_empty():
		print("\n--- FAILURES ---")
		for f in failures:
			print("  [FAIL] ", f)
		print("\nCOMPREHENSIVE AUDIT: FAILED")
		quit(1)
	else:
		print("\nCOMPREHENSIVE AUDIT: PASSED ALL CHECKS")
		quit(0)
