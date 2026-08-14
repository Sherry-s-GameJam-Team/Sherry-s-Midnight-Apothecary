extends RefCounted


static func run(test: TestSupport) -> void:
	var packed := load("res://day/levels/grassland/grass.tscn") as PackedScene
	test.expect(packed != null, "Grassland scene can be loaded.")
	if packed == null:
		return
	var grass := packed.instantiate() as GrasslandEnvironment
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child(grass)
	var skybox := grass.get_node("Skybox") as Parallax2D
	var corrupted_horizon := grass.get_node("CorruptedHorizon") as Parallax2D
	var far_grass := grass.get_node("FarGrass") as Parallax2D
	var player := grass.get_node("Player") as CharacterBody2D
	var default_entry := grass.get_node("EntryPoints/default") as Marker2D
	var camera := grass.get_node("Player/Camera2D") as Camera2D
	var foreground := grass.get_node("Foreground") as Node2D
	var dialog1_trigger := grass.get_node("issues/Dialog1Trigger") as GrasslandDialogueTrigger
	var sleeping_hound := grass.get_node("SleepingHoundNPC") as SleepingHoundNPC
	var sleeping_hound_tutorial := grass.get_node("SleepingHoundTutorial") as SleepingHoundTutorial

	test.expect_equal(skybox.scroll_scale, Vector2.ZERO, "Skybox stays fixed relative to the camera.")
	test.expect(grass.is_corrupted(), "Grassland starts in its day-zero corrupted state.")
	test.expect(corrupted_horizon.visible, "The corrupted horizon is visible in the day-zero corrupted state.")
	test.expect(corrupted_horizon.z_index > skybox.z_index and corrupted_horizon.z_index < far_grass.z_index, "The corrupted horizon renders between the skybox and far grass.")
	test.expect_equal(far_grass.scroll_scale, Vector2(0.45, 1.0), "Far grass uses horizontal-only parallax.")
	test.expect_equal(default_entry.global_position, player.global_position, "Grassland exposes a formal default travel entry point.")
	test.expect(foreground.z_index > player.z_index, "Foreground grass masks the player.")
	test.expect(dialog1_trigger != null and dialog1_trigger.dialogue_resource != null, "Crossing the dialog1 marker triggers its configured dialogue.")
	test.expect_equal(dialog1_trigger.seen_flag, "grassland_dialog1_seen", "dialog1 records its one-time trigger flag.")
	test.expect_equal(dialog1_trigger.destination_level, &"emerald_field", "dialog1's floating-island cinematic enters Emerald Field.")
	test.expect_equal(dialog1_trigger.player_path, NodePath("../../Player"), "dialog1 resolves Sherry for its boarding animation.")
	test.expect_equal(dialog1_trigger.trapezoid_path, NodePath("../../Trapezoid"), "dialog1 resolves the floating Trapezoid for its lift animation.")
	var dialog1_source := FileAccess.get_file_as_string("res://day/levels/grassland/dialog1.dialogue")
	test.expect(dialog1_source.contains('emit_dialogue_event("grassland_dialog1_board")'), "dialog1 starts the floating-island boarding cinematic before Sherry's surprise line.")
	test.expect(dialog1_source.contains('emit_dialogue_event("grassland_dialog1_launch")'), "dialog1 launches the floating island after Sherry's surprise line.")
	test.expect_equal(camera.position, Vector2(112, -291), "Town camera framing is preserved.")
	test.expect_equal(camera.limit_left, -2121, "Grassland camera follows the edited left world barrier.")
	test.expect_equal(camera.limit_right, 4550, "Grassland camera follows the edited right world barrier.")
	test.expect(grass.get_node("Foreground/GrassLoop") is Sprite2D, "grass_loop is installed in the foreground layer.")
	test.expect(sleeping_hound != null, "Grassland installs the sleeping hound interaction NPC.")
	test.expect(sleeping_hound_tutorial != null, "Grassland installs the sleeping hound purification tutorial controller.")
	var console := grass.get_node_or_null("DebugUI/DeveloperConsole")
	test.expect(console != null, "Standalone Grassland installs its developer console at runtime.")
	if console != null:
		test.expect((console.call("execute_command", "status") as String).contains("mode=DAY"), "Standalone Grassland binds the console to its day-scene controls.")
	test.expect(sleeping_hound.get_node("TargetGuide") is SleepingHoundTargetGuide, "Sleeping hound includes its purification target arrow.")

	var texture_paths: Array[NodePath] = [
		NodePath("Skybox/Artwork"),
		NodePath("FarGrass/Artwork"),
		NodePath("FarGrass/GrassLoop2"),
		NodePath("FarGrass/GrassLoop3"),
		NodePath("Foreground/GrassLoop2"),
		NodePath("Foreground/GrassLoop"),
	]
	var original_transforms := {}
	for node_path in texture_paths:
		original_transforms[node_path] = (grass.get_node(node_path) as Sprite2D).transform

	var changed_states: Array[bool] = []
	grass.texture_state_changed.connect(func(corrupted: bool) -> void: changed_states.append(corrupted))
	grass.texture_state_requested.emit(false)
	test.expect(not grass.is_corrupted(), "The corruption state can return to normal after purification.")
	test.expect(not corrupted_horizon.visible, "The corrupted horizon is hidden in the normal state.")
	grass.texture_state_requested.emit(true)
	test.expect(grass.is_corrupted(), "The request signal switches Grassland to corrupted textures.")
	test.expect_equal(changed_states, [false, true], "The changed signal reports both state transitions.")
	test.expect(corrupted_horizon.visible, "The corrupted horizon appears in the corrupted state.")
	test.expect((grass.get_node("Skybox/Artwork") as Sprite2D).texture.resource_path.ends_with("skybox_corruped.png"), "Corrupted skybox is applied.")
	test.expect((grass.get_node("FarGrass/Artwork") as Sprite2D).texture.resource_path.ends_with("fs_grass_corruped.png"), "Corrupted far grass is applied.")
	for node_path in texture_paths.slice(2):
		var sprite := grass.get_node(node_path) as Sprite2D
		test.expect(sprite.texture.resource_path.ends_with("grass_corrupted_loop.png"), "%s uses corrupted grass." % node_path)
	for node_path in texture_paths:
		test.expect_equal((grass.get_node(node_path) as Sprite2D).transform, original_transforms[node_path], "%s keeps its edited transform." % node_path)

	var grass_loops := grass.find_children("GrassLoop*", "Sprite2D", true, false)
	test.expect(not grass_loops.is_empty(), "Grassland exposes GrassLoop sprites for corruption.")
	for grass_loop: Sprite2D in grass_loops:
		test.expect(grass_loop.texture.resource_path.ends_with("grass_corrupted_loop.png"), "%s uses corrupted grass." % grass_loop.get_path())

	grass.texture_state_requested.emit(false)
	test.expect(not corrupted_horizon.visible, "The corrupted horizon hides when Grassland returns to normal.")

	grass.free()
