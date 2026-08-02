extends RefCounted

const ALCHEMY_SCENE := preload("res://night/alchemy/alchemy_runtime.tscn")


static func run(test: TestSupport) -> void:
	var runtime := ALCHEMY_SCENE.instantiate() as AlchemyRuntime
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child(runtime)
	runtime._sync_alchemy_background()
	var background := runtime.alchemy_background
	var background_width := background.texture.get_size().x * absf(background.scale.x)
	var stage_width := runtime.stage_root.size.x
	var furnace := runtime.furnace_fire
	test.expect(background.z_index < furnace.z_index, "Shared background renders behind the furnace.")
	test.expect_float_close(background.position.x - background_width * 0.5, 0.0, 0.01, "Brewing view aligns the background's left edge with the stage.")

	runtime.horizontal_stage.position.x = -runtime.production_panel.position.x
	runtime._sync_alchemy_background()
	test.expect_float_close(background.position.x + background_width * 0.5, stage_width, 0.01, "Production view aligns the background's right edge with the stage.")
	runtime.free()
