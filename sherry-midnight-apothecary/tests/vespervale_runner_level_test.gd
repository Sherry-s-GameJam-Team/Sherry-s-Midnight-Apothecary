extends RefCounted

const RUNNER_SCRIPT := preload("res://day/levels/Vespervale/runner.gd")


static func run(test: TestSupport) -> void:
	var level_data := load("res://day/levels/Vespervale/vespervale_runner_level.tres") as LevelData
	test.expect(level_data != null, "Vespervale Runner LevelData resource can be loaded.")
	if level_data != null:
		test.expect_equal(level_data.id, &"vespervale_runner", "LevelData id is vespervale_runner.")
		test.expect(level_data.content_scene != null, "LevelData content_scene is assigned.")
		test.expect_equal(level_data.default_entry_id, &"default", "Default entry id is default.")
		test.expect(level_data.display_name.length() > 0, "Display name is configured.")
		test.expect(level_data.disaster_name.length() > 0, "Disaster name is configured.")

	var packed := load("res://day/levels/Vespervale/runner.tscn") as PackedScene
	test.expect(packed != null, "Vespervale Runner scene can be loaded.")
	if packed == null:
		return

	var level: Node = packed.instantiate()
	test.expect(level != null, "Vespervale Runner scene instantiates.")
	if level == null:
		return

	if level.has_method("_ready"):
		level.call("_ready")

	test.expect(level is DayLevelEnvironment, "Runner root inherits from DayLevelEnvironment.")
	test.expect(level is VespervaleRunnerLevel, "Runner root is VespervaleRunnerLevel.")

	var ctrl := level.get_node_or_null("RunnerController") as RunnerController
	test.expect(ctrl != null, "RunnerController exists in runner scene.")
	if ctrl != null:
		if ctrl.has_method("_ready"):
			ctrl.call("_ready")
		test.expect(ctrl.is_running, "RunnerController starts in running state.")
		test.expect_equal(ctrl.total_duration, 120.0, "Total duration is configured to 120 seconds (2 minutes).")
		test.expect(ctrl.sherry != null, "RunnerController binds Sherry.")
		test.expect(ctrl.luca != null, "RunnerController binds Luca.")

		# Test Sherry W jump
		ctrl._sherry_on_floor = true
		ctrl._try_sherry_jump()
		test.expect(not ctrl._sherry_on_floor, "Sherry jumps into airborne state.")
		test.expect(ctrl._sherry_vel_y < 0.0, "Sherry has upward jump velocity.")

		# Test Luca Space jump
		ctrl._luca_on_floor = true
		ctrl._try_luca_jump()
		test.expect(not ctrl._luca_on_floor, "Luca jumps into airborne state.")
		test.expect(ctrl._luca_vel_y < 0.0, "Luca has upward jump velocity.")

	var hud := level.get_node_or_null("RunnerHUD") as RunnerHUD
	test.expect(hud != null, "RunnerHUD exists in runner scene.")

	var track_gen := level.get_node_or_null("TrackGenerator") as RunnerTrackGenerator
	test.expect(track_gen != null, "RunnerTrackGenerator exists in runner scene.")

	var finish_altar := level.get_node_or_null("World/FinishAltar")
	test.expect(finish_altar != null, "FinishAltar exists in runner scene.")
	if finish_altar != null:
		test.expect(finish_altar.has_node("ExitPortal"), "FinishAltar has ExitPortal.")

	level.free()
