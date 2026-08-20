extends RefCounted


static func run(test: TestSupport) -> void:
	var town_scene := load("res://day/levels/market/town/town.tscn") as PackedScene
	test.expect(town_scene != null, "Town scene with the event-controlled fountain loads.")
	if town_scene == null:
		return
	var town := town_scene.instantiate()
	var fountain := town.get_node_or_null("CS/Fountain") as MarketFountainEventAppearance
	var issue := town.get_node_or_null("issueDay1") as TownIssueDayOne
	test.expect(fountain != null, "Town Fountain uses the event appearance controller.")
	test.expect(issue != null and not issue.visible, "Town issueDay1 is serialized hidden outside its first-day performance.")
	test.expect(issue != null and issue.get_node_or_null("People") is Sprite2D, "Town issueDay1 owns the People camera-focus sprite.")
	test.expect(issue != null and issue.get_node_or_null("sherryposition") is Marker2D and issue.get_node_or_null("lucaposition") is Marker2D, "Town issueDay1 owns Sherry and Luca staging markers.")
	test.expect(issue != null and issue.get_node_or_null("Luca") is LucaPlayer, "Town issueDay1 supplies the staged Luca actor.")
	if fountain != null:
		test.expect(fountain.blood_fountain_enabled, "The blood-fountain Inspector switch defaults to enabled.")
		test.expect_equal(fountain.blood_fountain_day, 1, "The blood fountain is scoped to the first day.")
		test.expect_equal(fountain.blood_fountain_event_flag, &"lumen_street_blood_fountain_active", "The fountain has a stable persistent event switch.")
		var player := PlayerData.new()
		test.expect(fountain.should_use_blood_fountain(1, player), "The first day always uses blood-fountain frames for its opening event.")
		test.expect(not fountain.should_use_blood_fountain(2, player), "The blood-fountain reveal does not carry into later days.")
		fountain.blood_fountain_enabled = false
		test.expect(not fountain.should_use_blood_fountain(1, player), "The Inspector switch can disable the blood-fountain presentation.")
	town.free()
