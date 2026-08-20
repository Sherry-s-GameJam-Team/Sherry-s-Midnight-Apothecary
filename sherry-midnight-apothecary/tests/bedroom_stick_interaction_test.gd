extends RefCounted


static func run(test: TestSupport) -> void:
	var bedroom_scene := load("res://day/levels/home/bedroom.tscn") as PackedScene
	test.expect(bedroom_scene != null, "Bedroom scene with the stick interaction loads.")
	if bedroom_scene == null:
		return
	var bedroom := bedroom_scene.instantiate()
	var stick := bedroom.get_node_or_null("Stick") as BedroomStickInteraction
	var exit := bedroom.get_node_or_null("RightExit") as BedroomExit
	var player := bedroom.get_node_or_null("Player") as CharacterBody2D
	var wake_executor := bedroom.get_node_or_null("SleepToWakeExecutor") as AnimationPresentationExecutor
	var wake_overlay := bedroom.get_node_or_null("WakeReveal/FadeOverlay") as ColorRect
	var luca := bedroom.get_node_or_null("DayOneLuca/Luca") as LucaPlayer
	var luca_opening := bedroom.get_node_or_null("DayOneLuca") as BedroomDayOneLuca
	test.expect(player != null and not player.visible, "Bedroom serializes the complete player scene hidden before its first rendered frame.")
	test.expect(wake_executor != null and not wake_executor.auto_start, "Bedroom delegates the choice between the normal wake-up and the day-one Luca opening to its presentation controller.")
	test.expect(wake_overlay != null and wake_overlay.color.a == 1.0, "Bedroom starts behind an opaque viewport overlay before the wake animation begins.")
	test.expect(wake_executor != null and wake_executor.reveal_overlay_path == NodePath("../WakeReveal/FadeOverlay"), "The wake presentation owns the bedroom fade-in overlay.")
	test.expect(stick != null, "Bedroom Stick is connected to the interaction system.")
	test.expect(stick != null and stick.dialogue_resource != null, "Bedroom Stick has its one-shot intro dialogue.")
	test.expect(stick != null and stick.get_node_or_null("InteractionArea/CollisionShape2D") != null, "Bedroom Stick has a player interaction range.")
	test.expect(exit != null, "Bedroom right boundary uses the gated exit controller.")
	test.expect(exit != null and exit.locked_hint_text == "床头柜上贴着某张便签，先读读看吧", "The locked exit displays the requested note reminder.")
	test.expect(luca != null and not luca.input_enabled and luca.process_mode != Node.PROCESS_MODE_DISABLED, "Bedroom places an input-disabled Luca actor that can still run its walk animation for the day-one event.")
	test.expect(luca_opening != null and luca_opening.approach_x < luca.position.x, "Day-one Luca walks from the room entrance toward the bed before dialogue.")
	test.expect(bedroom.get_node_or_null("DayOneLuca/InteractionArea") == null, "Day-one Luca has no E-key interaction zone.")
	test.expect(BedroomDayOneLuca.should_show(1), "Bedroom Luca is visible on day one.")
	test.expect(not BedroomDayOneLuca.should_show(0), "Bedroom Luca is hidden on day zero.")
	bedroom.free()

	var dialogue_source := FileAccess.get_file_as_string("res://day/levels/home/bedroom_stick.dialogue")
	test.expect(dialogue_source.contains("~ start"), "Bedroom Stick dialogue has a start title.")
	test.expect(dialogue_source.contains("=> END"), "Bedroom Stick dialogue is finite and one-shot compatible.")
	var luca_dialogue := FileAccess.get_file_as_string("res://day/levels/home/day_one_bedroom_luca.dialogue")
	test.expect(luca_dialogue.contains("~ start") and luca_dialogue.contains("~ goto_town_square"), "Day-one Luca dialogue exposes its requested start and town-square handoff titles.")
	test.expect(luca_dialogue.contains("雪莉小姐，吾有急事相报，莫要不理吾……"), "Day-one Luca dialogue begins with Luca's urgent request.")
	test.expect(not luca_dialogue.contains("[") and not luca_dialogue.contains("]"), "Day-one Luca dialogue keeps stage directions out of dialogue text.")
	test.expect(not luca_dialogue.contains("Luca:") and luca_dialogue.contains("卢卡:"), "Day-one Luca dialogue uses Luca's Chinese name consistently.")
	var luca_event := load("res://shared/definitions/events/day_one_bedroom_luca_urgent.tres") as StoryEventDefinition
	var task_action: StoryEventAction = luca_event.actions[1] as StoryEventAction if luca_event != null and luca_event.actions.size() > 1 else null
	test.expect(task_action != null and task_action.task_title == "调查流明街广场的红色喷泉", "Day-one Luca dialogue assigns the red-fountain objective through its completion action.")
