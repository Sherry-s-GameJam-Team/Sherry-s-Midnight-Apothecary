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
	var far_grass := grass.get_node("FarGrass") as Parallax2D
	var player := grass.get_node("Player") as CharacterBody2D
	var camera := grass.get_node("Player/Camera2D") as Camera2D
	var foreground := grass.get_node("Foreground") as Node2D

	test.expect_equal(skybox.scroll_scale, Vector2.ZERO, "Skybox stays fixed relative to the camera.")
	test.expect_equal(far_grass.scroll_scale, Vector2(0.45, 1.0), "Far grass uses horizontal-only parallax.")
	test.expect(foreground.z_index > player.z_index, "Foreground grass masks the player.")
	test.expect_equal(camera.position, Vector2(112, -291), "Town camera framing is preserved.")
	test.expect_equal(camera.limit_left, 0, "Grassland camera starts at the left artwork edge.")
	test.expect_equal(camera.limit_right, 2168, "Grassland camera stops at the right artwork edge.")
	test.expect(grass.get_node("Foreground/GrassLoop") is Sprite2D, "grass_loop is installed in the foreground layer.")

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
	grass.texture_state_requested.emit(true)
	test.expect(grass.is_corrupted(), "The request signal switches Grassland to corrupted textures.")
	test.expect_equal(changed_states, [true], "The changed signal reports the corrupted state.")
	test.expect((grass.get_node("Skybox/Artwork") as Sprite2D).texture.resource_path.ends_with("skybox_corruped.png"), "Corrupted skybox is applied.")
	test.expect((grass.get_node("FarGrass/Artwork") as Sprite2D).texture.resource_path.ends_with("fs_grass_corruped.png"), "Corrupted far grass is applied.")
	for node_path in texture_paths.slice(2):
		var sprite := grass.get_node(node_path) as Sprite2D
		test.expect(sprite.texture.resource_path.ends_with("grass_corrupted_loop.png"), "%s uses corrupted grass." % node_path)
	for node_path in texture_paths:
		test.expect_equal((grass.get_node(node_path) as Sprite2D).transform, original_transforms[node_path], "%s keeps its edited transform." % node_path)

	var console := grass.get_node("DebugUI/DeveloperConsole") as DeveloperConsole
	test.expect_equal(console.execute_command("to normal"), "environment = normal", "Console restores normal Grassland textures.")
	test.expect(not grass.is_corrupted(), "Normal console command updates the scene state.")
	test.expect_equal(console.execute_command("to corrupted"), "environment = corrupted", "Console applies corrupted Grassland textures.")
	grass.free()
