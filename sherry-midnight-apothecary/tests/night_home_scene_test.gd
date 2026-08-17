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
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(runtime)
	runtime.configure(PlayerData.new(), 3)
	test.expect(runtime.customer_slot is CanvasLayer, "Night business runs in screen space instead of through the world camera.")
	test.expect(runtime.business_placeholder.player_data == runtime.player_data, "Business receives NightRuntime's shared PlayerData.")
	test.expect(runtime.business_placeholder.night_result == runtime.current_night_result, "Business writes into NightRuntime's current NightResult.")
	test.expect(runtime.alchemy_slot is CanvasLayer, "Night alchemy runs in screen space instead of through the world camera.")

	var home := runtime.get_node("ShopSlot/NightHome") as NightHome
	var bgm := runtime.get_node("InteriorNightBGM") as AudioStreamPlayer
	var player := home.get_node("Player") as CharacterBody2D
	var default_entry := home.get_node("EntryPoints/default") as Marker2D
	test.expect_equal(player.global_position, default_entry.global_position, "The night player starts at EntryPoints/default.")
	test.expect(home.get_node_or_null("NightLighting/AmbientTint") is CanvasModulate, "The night scene has a cool ambient tint.")
	test.expect(home.get_node_or_null("NightLighting/TableLamp") is PointLight2D, "The table has a warm local light.")
	test.expect(home.get_node_or_null("NightLighting/AlchemyLamp") is PointLight2D, "The alchemy station has a warm local light.")
	test.expect(home.get_node_or_null("InteriorNightBGM") == null, "Night BGM is owned by the persistent runtime, not the home room.")
	test.expect(bgm != null and bgm.playing, "The persistent night BGM is playing.")
	test.expect_equal(bgm.process_mode, Node.PROCESS_MODE_ALWAYS, "The persistent night BGM continues while the pause menu pauses gameplay.")
	var bgm_playback_position := bgm.get_playback_position()

	var table := home.get_node("Table") as NightStationInteraction
	var equip := home.get_node("Equip") as NightStationInteraction
	var transformer := home.get_node("Transsformer") as NightStationInteraction
	test.expect_equal(table.interaction_hint_text, "按[E]开始营业", "The table advertises the business interaction.")
	test.expect_equal(table.action, NightStationInteraction.Action.BUSINESS, "The table requests the business scene.")
	test.expect_equal(equip.action, NightStationInteraction.Action.PRODUCTION, "Equip requests the production workflow directly.")
	test.expect_equal(transformer.pressed_message, "夜晚还是不要出去了", "The transformer gives the night travel warning.")
	test.expect_equal(transformer.action, NightStationInteraction.Action.MESSAGE, "The transformer is message-only and cannot open the map.")
	test.expect(home.get_node_or_null("HomeCameraDirector") is HomeCameraDirector, "The night home reuses the day barrier and camera transition behavior.")
	test.expect(home.get_node_or_null("BedroomPortal") is NightBedroomPortal, "The opened bedroom area leads to a dedicated night bedroom scene.")

	test.expect(runtime.switch_room(&"bedroom", &"from_home"), "Night home can switch to the night bedroom.")
	var bedroom := runtime.get_node("ShopSlot/NightBedroom") as NightBedroom
	var bedroom_player := bedroom.get_node("Player") as CharacterBody2D
	var bedroom_entry := bedroom.get_node("EntryPoints/from_home") as Marker2D
	test.expect_equal(bedroom_player.global_position, bedroom_entry.global_position, "Entering the night bedroom uses its home-side marker.")
	test.expect(bedroom.get_node_or_null("NightLighting/AmbientTint") is CanvasModulate, "The bedroom inherits the night ambient treatment.")
	test.expect(bedroom.get_node_or_null("NightLighting/BedsideLamp") is PointLight2D, "The bedroom has a warm local light.")
	test.expect(runtime.get_node("InteriorNightBGM") == bgm, "Room switching preserves the same BGM player node.")
	test.expect(bgm.playing and bgm.get_playback_position() >= bgm_playback_position, "Room switching does not restart night BGM playback.")
	test.expect(runtime.switch_room(&"home", &"bedroomdoor"), "The night bedroom can return to night home.")
	home = runtime.get_node("ShopSlot/NightHome") as NightHome
	player = home.get_node("Player") as CharacterBody2D
	var bedroom_door_entry := home.get_node("EntryPoints/bedroomdoor") as Marker2D
	test.expect_equal(player.global_position, bedroom_door_entry.global_position, "Returning from the bedroom uses the home bedroom-door marker.")

	var luca_npc := home.get_node_or_null("LucaNightNPC") as LucaNightNPC
	test.expect(luca_npc != null, "NightHome contains the LucaNightNPC interaction node.")

	home.business_requested.emit()
	test.expect(not runtime.shop_slot.visible, "Opening business hides the explorable shop.")
	test.expect(runtime.customer_slot.visible, "Opening business shows the replaceable business scene.")
	test.expect(runtime.business_placeholder.potion_shelf_panel != null, "Opening business refreshes its potion shelf from current night data.")
	test.expect(not player.is_physics_processing(), "Opening business pauses player movement.")
	runtime.business_placeholder.request_return.emit()
	test.expect(runtime.shop_slot.visible, "Returning from business restores the shop.")
	test.expect(not runtime.customer_slot.visible, "Returning from business hides the placeholder scene.")
	test.expect(player.is_physics_processing(), "Returning from business restores player movement.")

	home.production_requested.emit()
	test.expect(runtime.alchemy_slot.visible, "Equip opens the existing night alchemy runtime.")
	test.expect(not runtime.shop_slot.visible, "Opening production hides the shop scene.")
	test.expect_equal(runtime.alchemy_runtime.current_panel, AlchemyRuntime.PanelMode.PRODUCTION, "Equip lands directly on the production panel.")
	test.expect(runtime.alchemy_runtime.size.x > 0.0 and runtime.alchemy_runtime.size.y > 0.0, "Night production fills a real viewport-sized Control canvas.")

	runtime.free()
