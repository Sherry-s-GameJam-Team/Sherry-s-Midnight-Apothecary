extends RefCounted

const ALCHEMY_SCENE := preload("res://night/alchemy/alchemy_runtime.tscn")


static func run(test: TestSupport) -> void:
	var runtime := ALCHEMY_SCENE.instantiate() as AlchemyRuntime
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child(runtime)

	var player := PlayerData.new()
	player.inventory = {&"dew_flask_herb": 2, &"herdsmans_loaf_bush": 2}
	var result := NightResult.new()

	# 1. Verification of Day 0 tutorial start
	runtime.setup(player, result, 0)
	var guide := runtime.tutorial_guide
	test.expect(guide != null, "AlchemyRuntime instantiates and wires AlchemyTutorialGuide.")
	test.expect(guide.is_active, "Alchemy tutorial guide starts active on Day 0.")
	test.expect_equal(guide.current_step, AlchemyTutorialGuide.Step.OPEN_CODEX, "Initial tutorial step is OPEN_CODEX.")

	# 2. Codex step progression
	var codex := runtime.spectrum_codex_panel
	test.expect(codex != null, "SpectrumCodexPanel is present.")
	codex.slide_open()
	guide._evaluate_step()
	test.expect_equal(guide.current_step, AlchemyTutorialGuide.Step.VIEW_CODEX, "Opening codex transitions to VIEW_CODEX.")
	codex.slide_closed()
	guide._evaluate_step()
	test.expect_equal(guide.current_step, AlchemyTutorialGuide.Step.GO_TO_PRODUCTION, "Closing codex transitions to GO_TO_PRODUCTION.")

	# 3. Production panel progression & Wrong herb rejection
	runtime.show_production_panel()
	guide._evaluate_step()
	test.expect_equal(guide.current_step, AlchemyTutorialGuide.Step.DRAG_HERB_TO_BOARD, "Switched to production panel transitions to DRAG_HERB_TO_BOARD.")

	var prod := runtime.production_panel
	test.expect(prod != null, "ProductionPanel is present.")

	# Try dropping wrong herb (herdsmans_loaf_bush) -> Should be rejected
	prod._on_herb_dropped(&"herdsmans_loaf_bush")
	test.expect(prod.pieces.is_empty(), "Wrong herb is rejected during tutorial and not added to board.")
	test.expect(prod.status_label.text.contains("露水水囊草"), "Status label shows prompt to choose dew_flask_herb.")

	# Put correct herb (dew_flask_herb) on process board
	var herb_data := runtime.ingredient_by_id(&"dew_flask_herb")
	test.expect(herb_data != null, "dew_flask_herb data exists.")
	prod._on_herb_dropped(&"dew_flask_herb")
	guide._evaluate_step()
	test.expect_equal(guide.current_step, AlchemyTutorialGuide.Step.SEPARATE_HERB, "Herb on board transitions to SEPARATE_HERB.")

	# Separate herb
	test.expect(prod.separate_herb(), "Separating herb succeeds.")
	guide._evaluate_step()
	test.expect_equal(guide.current_step, AlchemyTutorialGuide.Step.DRAG_PIECE_TO_GRIND, "Separated herb transitions to DRAG_PIECE_TO_GRIND.")

	# Move dew_flask piece to grind state
	for piece in prod.pieces:
		if piece.data != null and piece.data.id == &"dew_flask":
			piece.state = ProductionRuntimeTypes.HerbPieceRuntime.State.GRIND
			break
	guide._evaluate_step()
	test.expect_equal(guide.current_step, AlchemyTutorialGuide.Step.GRIND_POWDER, "Piece in grind zone transitions to GRIND_POWDER.")

	# Grind piece
	test.expect(prod.grind_selected_pieces(), "Grinding selected piece succeeds.")
	guide._evaluate_step()

	# Leaves are still on workbench -> Step must be DISCARD_LEAVES_TO_WASTE
	test.expect_equal(guide.current_step, AlchemyTutorialGuide.Step.DISCARD_LEAVES_TO_WASTE, "Remaining leaves on board require DISCARD_LEAVES_TO_WASTE before packing.")

	# Move all other pieces to WASTE zone
	for piece in prod.pieces:
		if piece.state == ProductionRuntimeTypes.HerbPieceRuntime.State.SEPARATED:
			piece.state = ProductionRuntimeTypes.HerbPieceRuntime.State.WASTE
	guide._evaluate_step()
	test.expect_equal(guide.current_step, AlchemyTutorialGuide.Step.PACK_POWDER, "Clean board with leaves in waste transitions to PACK_POWDER.")

	# Pack powder
	test.expect(prod.pack_powder(), "Packing powder succeeds.")
	prod._on_pack_timer_timeout()
	guide._evaluate_step()
	test.expect_equal(guide.current_step, AlchemyTutorialGuide.Step.BACK_TO_BREWING, "Packed powder transitions to BACK_TO_BREWING.")

	# Switch back to brewing panel
	runtime.show_brewing_panel()
	guide._evaluate_step()
	test.expect_equal(guide.current_step, AlchemyTutorialGuide.Step.DRAG_POWDER_TO_CAULDRON, "Back to brewing panel transitions to DRAG_POWDER_TO_CAULDRON.")

	# Drag powder to cauldron
	var powders: Array[PowderInstanceData] = runtime.powder_shelf_state.list_powders()
	test.expect(not powders.is_empty(), "Powder shelf contains the packed powder.")
	var powder_id: StringName = powders[0].instance_id
	test.expect(runtime.add_powder_to_cauldron(powder_id), "Adding powder to cauldron succeeds.")
	guide._evaluate_step()
	test.expect_equal(guide.current_step, AlchemyTutorialGuide.Step.START_BREW, "Powder in cauldron transitions to START_BREW.")

	# Start brew
	var brew_res := runtime.brew()
	test.expect(not brew_res.is_empty(), "Brew starts successfully.")
	guide._evaluate_step()
	test.expect_equal(guide.current_step, AlchemyTutorialGuide.Step.PUMP_BELLOWS, "Active brew transitions to PUMP_BELLOWS.")

	# Verify Bellows responds to space key and mouse click
	var bellows := runtime.bellows_control
	test.expect(bellows != null, "BellowsControl exists.")
	var pump_received := false
	var pump_handler := func(_val: float) -> void: pump_received = true
	bellows.bellows_pumped.connect(pump_handler)

	# Simulate Space key
	var space_event := InputEventKey.new()
	space_event.pressed = true
	space_event.keycode = KEY_SPACE
	bellows._unhandled_key_input(space_event)
	test.expect(pump_received, "BellowsControl receives SPACE key input.")

	pump_received = false
	bellows.pump_for_test()
	test.expect(pump_received, "BellowsControl pumps on direct invocation / mouse click.")
	bellows.bellows_pumped.disconnect(pump_handler)

	# Finish brewing -> Opens bottling panel
	runtime.heat_controller.complete_brew()
	guide._evaluate_step()
	test.expect_equal(guide.current_step, AlchemyTutorialGuide.Step.CONFIRM_BOTTLING, "Bottling panel transitions to CONFIRM_BOTTLING.")

	# Confirm bottling -> Complete tutorial
	runtime._on_bottling_confirmed(&"standard", "湛蓝净化药水")
	test.expect(not guide.is_active, "Confirming bottling deactivates tutorial guide.")
	test.expect(bool(player.tutorial_flags.get("day0_alchemy_tutorial_completed", false)), "Tutorial completed flag is saved in PlayerData.")

	# 4. Verification that non-day 0 or completed flags prevent guide from activating
	var runtime2 := ALCHEMY_SCENE.instantiate() as AlchemyRuntime
	scene_tree.root.add_child(runtime2)
	runtime2.setup(player, NightResult.new(), 1)
	test.expect(not runtime2.tutorial_guide.is_active, "Tutorial guide does not activate on Day 1.")

	runtime.queue_free()
	runtime2.queue_free()
