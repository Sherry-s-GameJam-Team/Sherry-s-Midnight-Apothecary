extends RefCounted

const HINT_AREA_SCENE := preload("res://day/interactables/hint_area.tscn")
const CONTROLLED_TEXT_HINT_SCENE := preload("res://day/interactables/control_system/controlled_text_hint.tscn")
const TOP_HINT_SCENE := preload("res://night/ui/top_hint/top_hint_ui.tscn")


static func run(test: TestSupport) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var top_hint := TOP_HINT_SCENE.instantiate() as TopHintUI
	tree.root.add_child(top_hint)

	var player := CharacterBody2D.new()
	player.name = "Player"
	tree.root.add_child(player)

	var hint_area := HINT_AREA_SCENE.instantiate() as HintArea
	hint_area.hint_text = "测试靠近提示"
	tree.root.add_child(hint_area)

	test.expect(hint_area._area != null, "HintArea exposes an Area2D child.")
	hint_area._area.body_entered.emit(player)
	test.expect(
		not top_hint._current.is_empty() and String(top_hint._current.get("text", "")) == "测试靠近提示",
		"HintArea shows the configured hint when the player enters the area."
	)

	hint_area._area.body_exited.emit(player)
	test.expect(top_hint._queue.is_empty(), "HintArea clears the hint queue when the player leaves the area.")

	top_hint.clear_all()
	hint_area._area.body_entered.emit(player)
	test.expect(
		not top_hint._current.is_empty() and String(top_hint._current.get("text", "")) == "测试靠近提示",
		"HintArea can show the hint again after a clear."
	)

	top_hint.clear_all()
	var text_hint := CONTROLLED_TEXT_HINT_SCENE.instantiate() as ControlledTextHint
	text_hint.hint_text = "测试受控提示"
	tree.root.add_child(text_hint)
	text_hint.set_controlled_active(true)
	test.expect(
		not top_hint._current.is_empty() and String(top_hint._current.get("text", "")) == "测试受控提示",
		"ControlledTextHint pushes its text when set_controlled_active(true) is called."
	)

	top_hint.clear_all()
	text_hint.set_controlled_active(false)
	text_hint.set_controlled_active(true)
	test.expect(
		not top_hint._current.is_empty() and String(top_hint._current.get("text", "")) == "测试受控提示",
		"ControlledTextHint can be reactivated after deactivation."
	)

	top_hint.clear_all()
	text_hint.free()
	hint_area.free()
	player.free()
	top_hint.free()
