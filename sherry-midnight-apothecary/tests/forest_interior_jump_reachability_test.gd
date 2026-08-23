extends SceneTree

const SCENE_PATH := "res://day/levels/forest/interior/forest_interior.tscn"

# Sherry Physics: walking jump 159px, running jump 213px => safe step spacing <= 100px
const SHERRY_SAFE_STEP_HEIGHT := 100.0

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		_fail("Unable to load %s" % SCENE_PATH)
		_finish()
		return
	var level := packed.instantiate() as ForestInteriorLevel
	root.add_child(level)
	await process_frame

	var reality := level.get_node_or_null("RealityWorld")
	if reality == null:
		_fail("RealityWorld missing")
		_finish()
		return

	# 1. Test Reality World Sequences for Sherry
	var stage2_seq := ["RightB", "StepB1", "StepB2", "StepB3", "StepB4", "MudStageRight", "MudShortcut", "MudStageLeft", "StepB5", "StepB6", "StepB7", "StepB8", "StepB9", "MidLanding"]
	_verify_sequence(reality, stage2_seq, "Stage 2 Staircase")

	var stage3_turret_seq := ["MidLanding", "StepS1", "StepS2", "StepS3", "SprayLeft"]
	_verify_sequence(reality, stage3_turret_seq, "Stage 3 Turret Approach")

	var stage3_cross_seq := ["SprayLeft", "SprayMid", "SprayStep1", "SprayRight", "StepT1", "StepT2", "StepT3", "StepT4", "StepT5", "ComboLeft"]
	_verify_sequence(reality, stage3_cross_seq, "Stage 3 Crossing")

	var stage4_seq := ["ComboLeft", "StepC1", "StepC2", "StepC3", "StepC4", "StepC5", "StepC6", "StepC7", "StepC8", "StepC9", "StepC10", "StepC11", "StepC12", "ControlLanding"]
	_verify_sequence(reality, stage4_seq, "Stage 4 Staircase")

	var stage5_seq := ["ControlLanding", "SherryUpper1", "StepCrown1", "StepCrown2", "StepCrown3", "SherryUpper2", "StepCrown4", "StepCrown5", "SherryUpper3", "StepCrown6", "StepCrown7", "StepCrown8", "TopLanding"]
	_verify_sequence(reality, stage5_seq, "Stage 5 Crown Staircase")

	level.queue_free()
	await process_frame
	_finish()

func _verify_sequence(parent: Node, node_names: Array, section_name: String) -> void:
	var prev_node: Node2D = null
	for name_str in node_names:
		var node := parent.get_node_or_null(str(name_str)) as Node2D
		if node == null:
			_fail("%s: Missing node %s" % [section_name, name_str])
			continue
		if prev_node != null:
			var dy := absf(node.position.y - prev_node.position.y)
			if dy > SHERRY_SAFE_STEP_HEIGHT:
				_fail("%s: Step from %s to %s dy (%.1f) exceeds safe step height (%.1f)" % [section_name, prev_node.name, node.name, dy, SHERRY_SAFE_STEP_HEIGHT])
		prev_node = node

func _fail(msg: String) -> void:
	failures.append(msg)
	push_error(msg)

func _finish() -> void:
	if failures.is_empty():
		print("FOREST_INTERIOR_JUMP_REACHABILITY_TEST: PASS")
		quit(0)
	else:
		print("FOREST_INTERIOR_JUMP_REACHABILITY_TEST: FAIL (%d)" % failures.size())
		for f in failures:
			print("  - ", f)
		quit(1)

