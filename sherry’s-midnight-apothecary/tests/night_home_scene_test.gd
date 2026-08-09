extends RefCounted


static func run(test: TestSupport) -> void:
	var runtime_scene := load("res://night/night_runtime.tscn") as PackedScene
	test.expect(runtime_scene != null, "The night runtime scene loads with the shop environment.")
	if runtime_scene == null:
		return
	var runtime := runtime_scene.instantiate() as NightRuntime
	test.expect(runtime != null, "The night runtime scene instantiates.")
	if runtime == null:
		return
	runtime.configure(PlayerData.new(), 3)

	var home := runtime.get_node("ShopSlot/NightHome") as NightHome
	var player := home.get_node("Player") as CharacterBody2D
	var default_entry := home.get_node("EntryPoints/default") as Marker2D
	test.expect_equal(player.global_position, default_entry.global_position, "The night player starts at EntryPoints/default.")
	test.expect(home.get_node_or_null("NightLighting/AmbientTint") is CanvasModulate, "The night scene has a cool ambient tint.")
	test.expect(home.get_node_or_null("NightLighting/TableLamp") is PointLight2D, "The table has a warm local light.")
	test.expect(home.get_node_or_null("NightLighting/AlchemyLamp") is PointLight2D, "The alchemy station has a warm local light.")

	var table := home.get_node("Table") as NightStationInteraction
	var transformer := home.get_node("Transsformer") as NightStationInteraction
	test.expect_equal(table.interaction_hint_text, "按[E]开始营业", "The table advertises the business interaction.")
	test.expect_equal(table.action, NightStationInteraction.Action.BUSINESS, "The table requests the business scene.")
	test.expect_equal(transformer.pressed_message, "夜晚还是不要出去了", "The transformer gives the night travel warning.")
	test.expect_equal(transformer.action, NightStationInteraction.Action.MESSAGE, "The transformer is message-only and cannot open the map.")

	home.business_requested.emit()
	test.expect(not runtime.shop_slot.visible, "Opening business hides the explorable shop.")
	test.expect(runtime.customer_slot.visible, "Opening business shows the replaceable business scene.")
	test.expect(not player.is_physics_processing(), "Opening business pauses player movement.")
	runtime.business_placeholder.request_return.emit()
	test.expect(runtime.shop_slot.visible, "Returning from business restores the shop.")
	test.expect(not runtime.customer_slot.visible, "Returning from business hides the placeholder scene.")
	test.expect(player.is_physics_processing(), "Returning from business restores player movement.")

	home.alchemy_requested.emit()
	test.expect(runtime.alchemy_slot.visible, "The alchemy station opens the existing night alchemy runtime.")
	test.expect(not runtime.shop_slot.visible, "Opening alchemy hides the shop scene.")

	runtime.free()
