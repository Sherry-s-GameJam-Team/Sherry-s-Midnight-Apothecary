extends RefCounted


static func run(test: TestSupport) -> void:
	var scene := load("res://night/ui/top_hint/top_hint_ui.tscn") as PackedScene
	test.expect(scene != null, "TopHintUI scene loads.")
	if scene == null:
		return
	var hint := scene.instantiate() as TopHintUI
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(hint)
	test.expect(hint is Control and hint.mouse_filter == Control.MOUSE_FILTER_IGNORE, "TopHintUI is a non-blocking Control owned by the shared GlobalUI layer.")
	test.expect(InputMap.has_action("hint_expand"), "hint_expand exists in the Input Map.")
	test.expect(InputMap.has_action("hint_skip"), "hint_skip exists in the Input Map.")
	var player := PlayerData.new()
	hint.bind_player_data(player)
	var diagram := load("res://night/art/ui/ornament.svg") as Texture2D
	hint.push_image_hint("按 E 查看图示。", diagram, "top_hint_test_image", "测试图示", true, 0.0)
	test.expect(hint._current_has_image, "An unseen image hint exposes the expand control.")
	hint._set_image_expanded(true)
	test.expect(bool(player.tutorial_flags.get("top_hint_test_image", false)), "Opening an image persists its viewed state.")
	test.expect(hint._image_reveal.visible, "Image reveal is visible while its linear height tween runs.")
	test.expect(hint._expand_row.visible, "Expanded image hints keep E available for collapse.")
	hint.clear_all()
	hint.push_image_hint("再次触发。", diagram, "top_hint_test_image", "测试图示", true, 0.0)
	test.expect(not hint._current_has_image, "An image_once hint becomes text-only after it has been viewed.")
	hint.free()
