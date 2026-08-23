extends SceneTree

const SCENE_PATH := "res://day/levels/forest/interior/forest_interior.tscn"

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		_fail("Unable to load %s" % SCENE_PATH)
		_finish()
		return
	var level := packed.instantiate()
	root.add_child(level)
	await process_frame
	for path in [
		"EntryPoints/default",
		"EntryPoints/from_forest",
		"Player",
		"Player/Camera2D",
		"Player/PotionThrower",
		"RealityWorld/RootLiftA",
		"RealityWorld/RotatingRoot",
		"RealityWorld/SluiceGate",
		"RealityWorld/RootLiftB",
		"RealityWorld/FinalGate",
		"RealityWorld/LiftAConsoleReality",
		"RealityWorld/LiftAConsole",
		"RealityWorld/SprayDevice",
		"RealityWorld/RotateConsole",
		"RealityWorld/SluiceConsole",
		"RealityWorld/LiftBConsole",
		"RealityWorld/FinalGateConsole",
		"RealityWorld/UpperControlRoom/DirectLift",
		"ExitToCrown",
	]:
		if level.get_node_or_null(path) == null:
			_fail("Missing required node: %s" % path)
	if level.has_method("set_corrupted"):
		level.call("set_corrupted", false)
		await process_frame
		level.call("set_corrupted", true)
	else:
		_fail("ForestInterior does not expose set_corrupted")
	level.queue_free()
	await process_frame
	_finish()

func _fail(message: String) -> void:
	failures.append(message)
	push_error(message)

func _finish() -> void:
	if failures.is_empty():
		print("FOREST_INTERIOR_SMOKE_TEST: PASS")
		quit(0)
	else:
		print("FOREST_INTERIOR_SMOKE_TEST: FAIL (%d)" % failures.size())
		quit(1)
