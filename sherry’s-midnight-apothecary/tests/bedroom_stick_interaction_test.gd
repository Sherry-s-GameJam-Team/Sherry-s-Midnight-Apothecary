extends RefCounted


static func run(test: TestSupport) -> void:
	var bedroom_scene := load("res://day/levels/home/bedroom.tscn") as PackedScene
	test.expect(bedroom_scene != null, "Bedroom scene with the stick interaction loads.")
	if bedroom_scene == null:
		return
	var bedroom := bedroom_scene.instantiate()
	var stick := bedroom.get_node_or_null("Stick") as BedroomStickInteraction
	var exit := bedroom.get_node_or_null("RightExit") as BedroomExit
	test.expect(stick != null, "Bedroom Stick is connected to the interaction system.")
	test.expect(stick != null and stick.dialogue_resource != null, "Bedroom Stick has its one-shot intro dialogue.")
	test.expect(stick != null and stick.get_node_or_null("InteractionArea/CollisionShape2D") != null, "Bedroom Stick has a player interaction range.")
	test.expect(exit != null, "Bedroom right boundary uses the gated exit controller.")
	test.expect(exit != null and exit.locked_hint_text == "床头柜上贴着某张便签，先读读看吧", "The locked exit displays the requested note reminder.")
	bedroom.free()

	var dialogue_source := FileAccess.get_file_as_string("res://day/levels/home/bedroom_stick.dialogue")
	test.expect(dialogue_source.contains("~ start"), "Bedroom Stick dialogue has a start title.")
	test.expect(dialogue_source.contains("=> END"), "Bedroom Stick dialogue is finite and one-shot compatible.")
