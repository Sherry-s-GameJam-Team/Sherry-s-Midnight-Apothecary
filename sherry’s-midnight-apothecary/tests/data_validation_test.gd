extends RefCounted


static func run(test: TestSupport) -> void:
	var registry := DataRegistry.new()
	registry.report_errors_to_engine = false
	var first := IngredientDefinition.new()
	first.id = &"moon_mint"
	first.display_name = "Moon Mint"
	var duplicate := IngredientDefinition.new()
	duplicate.id = &"moon_mint"
	duplicate.display_name = "Duplicate Moon Mint"
	var empty := IngredientDefinition.new()
	var missing_scene := LevelDefinition.new()
	missing_scene.id = &"forest"
	var missing_primary_id := DayDefinition.new()
	missing_primary_id.level_id = &"forest"

	test.expect(registry.register_definition(first), "A valid definition registers.")
	test.expect(not registry.register_definition(duplicate), "A duplicate definition ID is rejected.")
	test.expect(not registry.register_definition(empty), "An empty definition ID is rejected.")
	test.expect(not registry.register_definition(missing_scene), "A missing PackedScene is rejected.")
	test.expect(not registry.register_definition(missing_primary_id), "A related ID cannot replace an empty primary definition ID.")
	test.expect_equal(registry.size(), 1, "Only the valid definition remains registered.")
	test.expect(registry.get_errors().size() == 4, "Registry reports all validation errors.")
