extends RefCounted


static func run(test: TestSupport) -> void:
	var home_scene := load("res://day/levels/home/home.tscn") as PackedScene
	test.expect(home_scene != null, "Home scene with the day-one intro loads.")
	if home_scene == null:
		return
	var home := home_scene.instantiate()
	var intro := home.get_node_or_null("DayOneIntro") as HomeDayOneIntro
	var director := home.get_node_or_null("HomeCameraDirector") as HomeCameraDirector
	test.expect(intro != null, "Home installs the day-one NPC intro controller.")
	test.expect(director != null and director.has_method("focus_cinematic_camera"), "Home camera supports the cinematic focus override.")
	test.expect(home.get_node_or_null("Cinematic/YoungKnight") is Sprite2D, "Home includes the young knight cinematic visual.")
	test.expect(home.get_node_or_null("Cinematic/SeniorKnight") is Sprite2D, "Home includes the senior knight cinematic visual.")
	test.expect(home.get_node_or_null("Cinematic/trid") is Marker2D, "Home includes the player-position trigger marker.")
	var fade_overlay := home.get_node_or_null("CinematicFade/FadeOverlay") as ColorRect
	test.expect(fade_overlay != null, "Home includes the full-screen cinematic fade overlay.")
	test.expect(fade_overlay != null and fade_overlay.offset_left == 0.0 and fade_overlay.offset_top == 0.0 and fade_overlay.offset_right == 0.0 and fade_overlay.offset_bottom == 0.0, "The cinematic fade has no inset offsets and covers the entire camera viewport.")
	test.expect(intro != null and intro.dialogue_resource != null, "Home intro has an assigned Dialogue Manager resource.")
	var table := home.get_node("Table") as Sprite2D
	var young_knight := home.get_node("Cinematic/YoungKnight") as Sprite2D
	var senior_knight := home.get_node("Cinematic/SeniorKnight") as Sprite2D
	test.expect(young_knight.z_index > table.z_index and senior_knight.z_index > table.z_index, "Both cinematic NPCs render above the table.")

	var fresh_data := PlayerData.new()
	test.expect(HomeDayOneIntro.should_present(0, fresh_data), "A fresh day-zero save presents the Home intro.")
	test.expect(not HomeDayOneIntro.should_present(1, fresh_data), "Days after day zero skip the Home intro.")
	fresh_data.tutorial_flags[HomeDayOneIntro.COMPLETED_FLAG] = true
	test.expect(not HomeDayOneIntro.should_present(0, fresh_data), "The persistent completion flag prevents replay.")
	test.expect(HomeDayOneIntro.has_reached_trigger(Vector2(360, 710), Vector2(367, 846), 80.0), "The side-scrolling trigger uses horizontal arrival at trid despite the player foot-anchor offset.")
	test.expect(not HomeDayOneIntro.has_reached_trigger(Vector2(200, 846), Vector2(367, 846), 80.0), "The intro stays idle before the player reaches trid.")
	home.free()

	var dialogue_source := FileAccess.get_file_as_string("res://day/levels/home/home_day_one_intro.dialogue")
	for speaker in ["年轻士兵:", "中年士兵:", "雪莉:"]:
		test.expect(dialogue_source.contains(speaker), "Home intro dialogue includes %s" % speaker)
	test.expect(dialogue_source.contains("=> END"), "Home intro dialogue has a finite ending.")
