extends RefCounted


static func run(test: TestSupport) -> void:
	# Test 1: Load and verify village scene structure
	var village_scene := load("res://day/levels/golden_cliff/village/village.tscn") as PackedScene
	test.expect(village_scene != null, "Village scene loads successfully.")
	if village_scene == null:
		return

	var village := village_scene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	var hint_scene := load("res://night/ui/top_hint/top_hint_ui.tscn") as PackedScene
	var hint_ui := hint_scene.instantiate() as TopHintUI
	tree.root.add_child(hint_ui)
	tree.root.add_child(village)
	var issues := village.get_node_or_null("issues") as VillageDayTwoIssue
	test.expect(issues != null, "Village scene contains the day-two issues controller.")
	var mew_npc := village.get_node_or_null("CS/issue_Mews") as MewNPC
	if mew_npc == null:
		mew_npc = village.get_node_or_null("issues/issue_Mews") as MewNPC
	test.expect(mew_npc != null, "Village scene contains MewNPC at CS/issue_Mews or issues/issue_Mews.")
	if mew_npc == null:
		village.free()
		return

	test.expect(mew_npc.dialogue_resource != null, "MewNPC has a dialogue resource assigned.")
	test.expect_equal(mew_npc.interaction_hint_text, "按[E]与喵斯交谈", "Village Mew prompt uses the name 喵斯.")
	test.expect(mew_npc.ping_pong, "MewNPC has ping_pong enabled by default.")
	test.expect_equal(mew_npc.animation_name, &"fishing", "MewNPC targets the fishing animation.")
	test.expect(mew_npc.get_node_or_null("FishingLoop") is AnimatedSprite2D, "MewNPC contains the FishingLoop AnimatedSprite2D child.")
	test.expect(mew_npc.get_node_or_null("CollisionShape2D") is CollisionShape2D, "MewNPC contains a CollisionShape2D for player interaction.")
	test.expect(village.get_node_or_null("issues/down") is Marker2D, "Village issues contain the down crossing marker.")
	test.expect(village.get_node_or_null("CS/saved/IdleLoop") is AnimatedSprite2D, "Village saved foreground contains the gated IdleLoop sprite.")
	var rope_root := village.get_node_or_null("CS/rope") as Node2D
	test.expect(rope_root != null, "Village foreground contains the rope collection root.")
	if rope_root != null:
		var rope_count := 0
		for child in rope_root.get_children():
			if child is Sprite2D:
				rope_count += 1
		test.expect_equal(rope_count, 6, "Village contains six collectible rope sprites.")

	# Test 2: Ping-pong animation frame progression logic
	var sprite := mew_npc.get_node("FishingLoop") as AnimatedSprite2D
	test.expect(sprite.sprite_frames != null, "FishingLoop has SpriteFrames.")
	var frame_count: int = sprite.sprite_frames.get_frame_count(&"fishing")
	test.expect_equal(frame_count, 40, "Fishing animation has 40 frames.")

	# Start at frame 0
	mew_npc._animation_time = 0.0
	mew_npc._process(0.0)
	test.expect_equal(sprite.frame, 0, "Initial ping-pong frame is 0.")

	# Advance halfway forward (frame 20 at 8 fps = 2.5s)
	mew_npc._process(2.5)
	test.expect_equal(sprite.frame, 20, "Ping-pong advances forward to frame 20.")

	# Advance to end of forward pass (frame 39 at 8 fps = 4.875s total)
	mew_npc._animation_time = 39.0
	mew_npc._process(0.0)
	test.expect_equal(sprite.frame, 39, "Ping-pong reaches the peak at frame 39.")

	# Advance into reverse pass (cycle index 40 = frame 38)
	mew_npc._animation_time = 40.0
	mew_npc._process(0.0)
	test.expect_equal(sprite.frame, 38, "Ping-pong begins reversing smoothly to frame 38.")

	# Advance near end of reverse pass (cycle index 77 = frame 1)
	mew_npc._animation_time = 77.0
	mew_npc._process(0.0)
	test.expect_equal(sprite.frame, 1, "Ping-pong nears start on reverse pass at frame 1.")

	# Advance to full cycle completion (cycle index 78 wraps to 0)
	mew_npc._animation_time = 78.0
	mew_npc._process(0.0)
	test.expect_equal(sprite.frame, 0, "Ping-pong wraps seamlessly back to frame 0.")

	# Test 3: Player proximity interaction logic
	var player := village.get_node_or_null("Player") as CharacterBody2D
	test.expect(player != null, "Village contains the Player node.")
	test.expect(not mew_npc._player_inside, "Player is initially not inside Mew's interaction area.")

	mew_npc._on_body_entered(player)
	test.expect(mew_npc._player_inside, "Entering Mew's Area2D registers player inside.")
	test.expect_equal(mew_npc._player, player, "MewNPC references the player.")
	test.expect_equal(mew_npc._resolve_hint_ui(), hint_ui, "Mew resolves the shared HintUI presentation.")
	test.expect_equal(String(hint_ui._current.get("text", "")), mew_npc.interaction_hint_text, "Entering Mew's area displays its interaction text through HintUI.")

	mew_npc._on_body_exited(player)
	test.expect(not mew_npc._player_inside, "Exiting Mew's Area2D unregisters player.")

	hint_ui.clear_all()
	village.free()
	hint_ui.free()

	# Test 4: Verify mew.dialogue file validity and 4-question progression
	var dialogue_source := FileAccess.get_file_as_string("res://characters/mew/mew.dialogue")
	test.expect(dialogue_source.contains("~ start"), "mew.dialogue contains a start title.")
	test.expect(dialogue_source.contains("~ question_loop"), "mew.dialogue contains question_loop.")
	test.expect(dialogue_source.contains("~ question_menu"), "mew.dialogue contains question_menu.")
	test.expect(dialogue_source.contains("asked_mayor"), "mew.dialogue tracks asked_mayor.")
	test.expect(dialogue_source.contains("asked_village"), "mew.dialogue tracks asked_village.")
	test.expect(dialogue_source.contains("asked_father"), "mew.dialogue tracks asked_father.")
	test.expect(dialogue_source.contains("asked_potion"), "mew.dialogue tracks asked_potion.")
	test.expect(dialogue_source.contains("=> END"), "mew.dialogue terminates properly with END.")

	# Test 5: day-two down event uses the Mew dialogue and delivery prerequisite.
	var event := load("res://shared/definitions/events/village_day_two_down.tres") as StoryEventDefinition
	test.expect(event != null, "Village day-two down story event loads.")
	if event != null:
		test.expect_equal(event.trigger.interaction_key, &"village_day_two_down", "Village down event uses the expected interaction key.")
		test.expect_equal(event.dialogue_resource.resource_path, "res://characters/mew/mew.dialogue", "Village down event reuses Mew's dialogue resource.")
		test.expect_equal(event.dialogue_title, &"question_menu", "Village down event enters Mew's follow-up dialogue title.")
		var day_condition: StoryEventCondition = event.conditions[0] as StoryEventCondition
		test.expect(day_condition != null and day_condition.minimum_day == 2 and day_condition.maximum_day == 2, "Village day-two event is restricted to internal day two.")
		test.expect_equal(event.conditions.size(), 3, "Village down event requires day, order delivery, and ropes.")
		test.expect_equal(event.conditions[2].key, &"village_rope_spool", "Village down event requires collected rope spools.")
		test.expect_equal(event.conditions[2].amount, 5, "Village down event requires five rope spools.")
