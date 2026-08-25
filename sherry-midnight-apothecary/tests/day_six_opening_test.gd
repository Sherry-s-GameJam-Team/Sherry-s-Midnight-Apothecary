extends RefCounted


static func run(test: TestSupport) -> void:
	var bedroom_packed := load("res://day/levels/home/bedroom.tscn") as PackedScene
	test.expect(bedroom_packed != null, "Bedroom scene loads with the day-six opening.")
	if bedroom_packed != null:
		var bedroom := bedroom_packed.instantiate()
		test.expect(bedroom.get_node_or_null("DaySixOpening") is DaySixOpening, "Bedroom owns the day-six opening presentation.")
		bedroom.free()

	var data := PlayerData.new()
	test.expect(DaySixOpening.should_present(6, data), "Fresh day six presents the apothecary gate opening.")
	test.expect(not DaySixOpening.should_present(5, data), "Other days skip the day-six opening.")
	data.set_event_flag(DaySixOpening.HOME_COMPLETE_FLAG)
	test.expect(not DaySixOpening.should_present(6, data), "Completed apothecary segment does not replay.")
	data.set_event_flag(DaySixCrownlandEscort.PENDING_FLAG)
	test.expect(DaySixCrownlandEscort.should_present(6, data), "Pending day-six escort starts in Crownland.")
	data.set_event_flag(DaySixCrownlandEscort.COMPLETE_FLAG)
	test.expect(not DaySixCrownlandEscort.should_present(6, data), "Completed Crownland escort does not replay.")

	var arrival_packed := load("res://day/levels/crownland/home.tscn") as PackedScene
	test.expect(arrival_packed != null, "Old Gate Site arrival presentation loads.")
	var crownland_packed := load("res://day/levels/crownland/crownland.tscn") as PackedScene
	test.expect(crownland_packed != null, "Crownland scene loads with day-six escort actors.")
	if crownland_packed != null:
		var crownland := crownland_packed.instantiate()
		test.expect(crownland.get_node_or_null("DaySixCrownlandEscort") is DaySixCrownlandEscort, "Crownland owns the escort controller.")
		test.expect(crownland.get_node_or_null("DaySixParty/Enzuo") is AnimatedSprite2D, "Enzuo walk sprite is instanced for the Crownland march.")
		test.expect(crownland.get_node_or_null("DaySixParty/Luca") is LucaPlayer, "Luca walk scene is instanced for the Crownland march.")
		var enzuo := crownland.get_node_or_null("DaySixParty/Enzuo") as AnimatedSprite2D
		test.expect(enzuo != null and enzuo.offset.y < 0.0, "Enzuo's sprite origin is shifted so its feet sit on the Ground baseline.")
		crownland.free()

	var home_source := FileAccess.get_file_as_string("res://day/levels/home/day_six_opening.gd")
	test.expect(not home_source.contains("characters/sherry") and not home_source.contains("characters/enzuo") and not home_source.contains("characters/luca"), "Apothecary and arrival segment does not instance scene character textures.")
	var escort_source := FileAccess.get_file_as_string("res://day/levels/crownland/day_six_crownland_escort.gd")
	test.expect(escort_source.contains("global_position:x") and escort_source.contains("_ground_surface_y"), "Crownland party movement follows Ground and only interpolates horizontally.")
