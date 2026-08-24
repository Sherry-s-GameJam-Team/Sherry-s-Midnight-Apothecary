class_name SpectrumCodexTest
extends RefCounted

const PotionSpectrumCatalogScript := preload("res://night/ui/spectrum_codex/scripts/potion_spectrum_catalog.gd")
const PotionSpectrumBandScript := preload("res://night/ui/spectrum_codex/scripts/potion_spectrum_band.gd")
const PotionFunctionDefinitionScript := preload("res://night/ui/spectrum_codex/scripts/potion_function_definition.gd")
const PotionRecipeDefinitionScript := preload("res://night/ui/spectrum_codex/scripts/potion_recipe_definition.gd")
const PotionSpectrumUnlockStateScript := preload("res://night/ui/spectrum_codex/scripts/potion_spectrum_unlock_state.gd")
const SpectrumCodexPanelScript := preload("res://night/ui/spectrum_codex/scripts/spectrum_codex_panel.gd")
const SpectrumCodexDemoScript := preload("res://night/ui/spectrum_codex/scripts/spectrum_codex_demo.gd")


static func run(test: TestSupport) -> void:
	# 1. Catalog resource integrity
	var catalog_res := load("res://night/ui/spectrum_codex/resources/default_potion_spectrum_catalog.tres") as PotionSpectrumCatalog
	test.expect(catalog_res != null, "Default potion spectrum catalog loads successfully.")
	test.expect(catalog_res.bands.size() == 7, "Default catalog has 7 color bands.")
	test.expect(catalog_res.functions.size() >= 14, "Default catalog has at least 14 function branches.")
	test.expect(catalog_res.recipes.size() >= 14, "Default catalog has at least 14 recipes.")

	var band_red := catalog_res.get_band(&"band_red")
	test.expect(band_red != null and band_red.primary_effect_name.contains("止血"), "Red band primary effect is defined.")
	var func_hemo := catalog_res.get_function(&"func_hemostasis")
	test.expect(func_hemo != null and func_hemo.band_id == &"band_red", "Hemostasis function belongs to red band.")
	var rec_paste := catalog_res.get_recipe(&"recipe_blood_stop_paste")
	test.expect(rec_paste != null and rec_paste.function_id == &"func_hemostasis", "Blood stop paste belongs to hemostasis.")

	# 2. Unlock state integrity
	var unlock_state_res := load("res://night/ui/spectrum_codex/resources/default_potion_spectrum_unlock_state.tres") as PotionSpectrumUnlockState
	test.expect(unlock_state_res != null, "Default unlock state loads successfully.")
	test.expect(unlock_state_res.is_function_unlocked(&"func_hemostasis"), "Initial hemostasis function is unlocked.")
	test.expect(unlock_state_res.is_recipe_unlocked(&"recipe_blood_stop_paste"), "Initial blood paste recipe is unlocked.")
	test.expect(not unlock_state_res.is_recipe_unlocked(&"recipe_astral_clarity"), "Astral clarity recipe is initially locked.")

	# 3. Panel instantiation & scene hierarchy
	var panel_scene := load("res://night/ui/spectrum_codex/scenes/spectrum_codex_panel.tscn") as PackedScene
	test.expect(panel_scene != null, "SpectrumCodexPanel scene loads successfully.")

	var tree := Engine.get_main_loop() as SceneTree
	var root := tree.root if tree else null
	var panel := panel_scene.instantiate() as SpectrumCodexPanel
	test.expect(panel != null, "SpectrumCodexPanel can be instantiated.")

	if root != null:
		root.add_child(panel)

	# 4. State manipulation & runtime unlocking
	var custom_unlock_state := PotionSpectrumUnlockStateScript.new() as PotionSpectrumUnlockState
	panel.set_unlock_state(custom_unlock_state)
	test.expect(not custom_unlock_state.is_recipe_unlocked(&"recipe_astral_clarity"), "New state starts with recipe locked.")
	panel.unlock_recipe(&"recipe_astral_clarity")
	test.expect(custom_unlock_state.is_recipe_unlocked(&"recipe_astral_clarity"), "unlock_recipe marks recipe as unlocked.")

	panel.unlock_function(&"func_spirit_focus")
	test.expect(custom_unlock_state.is_function_unlocked(&"func_spirit_focus"), "unlock_function marks function as unlocked.")

	# 5. View mode switching
	var mode_state := {"emitted": false, "mode": &""}
	panel.view_mode_changed.connect(func(m: StringName) -> void:
		mode_state["emitted"] = true
		mode_state["mode"] = m
	)
	panel.set_view_mode(&"matrix")
	test.expect(mode_state["emitted"] and mode_state["mode"] == &"matrix", "set_view_mode switches to matrix view and emits signal.")
	test.expect(panel.current_view_mode == SpectrumCodexPanel.ViewMode.MATRIX, "Panel internal mode is MATRIX.")
	test.expect(panel.matrix_view.visible, "Matrix view control is visible in matrix mode.")
	test.expect(not panel.vertical_view.visible, "Vertical view control is hidden in matrix mode.")

	panel.set_view_mode(&"vertical")
	test.expect(panel.current_view_mode == SpectrumCodexPanel.ViewMode.VERTICAL, "Panel internal mode is VERTICAL.")
	test.expect(panel.vertical_view.visible, "Vertical view control is visible in vertical mode.")

	# 6. Scrolling & drag navigation verification
	panel.vertical_view.reset_view()
	test.expect(panel.vertical_view.scroll_container.scroll_vertical == 0, "reset_view restores scroll position to top.")

	# Wheel down simulation (scrolls content down)
	var wheel_down_event := InputEventMouseButton.new()
	wheel_down_event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel_down_event.pressed = true
	wheel_down_event.global_position = Vector2(100, 100)
	panel.vertical_view._on_gui_input(wheel_down_event)
	test.expect(panel.vertical_view.scroll_container.scroll_vertical > 0, "Mouse wheel down scrolls vertical view downwards.")

	# Test Left Mouse Drag simulation
	var drag_event_down := InputEventMouseButton.new()
	drag_event_down.button_index = MOUSE_BUTTON_LEFT
	drag_event_down.pressed = true
	drag_event_down.global_position = Vector2(100, 100)
	panel.vertical_view._on_gui_input(drag_event_down)
	test.expect(panel.vertical_view.is_dragging, "Left mouse button initiates panning drag.")

	var drag_event_move := InputEventMouseMotion.new()
	drag_event_move.global_position = Vector2(100, 80)
	panel.vertical_view._on_gui_input(drag_event_move)

	var drag_event_up := InputEventMouseButton.new()
	drag_event_up.button_index = MOUSE_BUTTON_LEFT
	drag_event_up.pressed = false
	panel.vertical_view._on_gui_input(drag_event_up)
	test.expect(not panel.vertical_view.is_dragging, "Releasing left mouse ends panning drag.")

	# 7. Focus & selection signal verification
	var recipe_signal_fired := {"fired": false, "id": &""}
	panel.recipe_selected.connect(func(r_id: StringName) -> void:
		recipe_signal_fired["fired"] = true
		recipe_signal_fired["id"] = r_id
	)
	panel.focus_recipe(&"recipe_blood_stop_paste")
	test.expect(recipe_signal_fired["fired"] and recipe_signal_fired["id"] == &"recipe_blood_stop_paste", "focus_recipe emits recipe_selected signal.")

	var function_signal_fired := {"fired": false, "id": &""}
	panel.function_selected.connect(func(f_id: StringName) -> void:
		function_signal_fired["fired"] = true
		function_signal_fired["id"] = f_id
	)
	panel.focus_function(&"func_hemostasis")
	test.expect(function_signal_fired["fired"] and function_signal_fired["id"] == &"func_hemostasis", "focus_function emits function_selected signal.")

	# 8. Matrix cell selection verification
	panel.set_view_mode(&"matrix")
	panel.matrix_view.select_cell(0, 0)
	test.expect(panel.detail_title.text.contains("止血"), "Detail title reflects selected matrix cell.")

	# 9. Custom Catalog data-driven extensibility test
	var custom_catalog := PotionSpectrumCatalogScript.new() as PotionSpectrumCatalog
	var band1 := PotionSpectrumBandScript.new() as PotionSpectrumBand
	band1.id = &"band_custom"
	band1.display_name = "异界波段"
	band1.color = Color.MAGENTA
	band1.primary_effect_name = "虚空折跃"
	custom_catalog.bands = [band1]
	custom_catalog.matrix_row_labels = ["虚空"]
	custom_catalog.matrix_col_labels = ["折跃"]

	panel.set_catalog(custom_catalog)
	test.expect(panel.catalog == custom_catalog, "set_catalog updates panel catalog reference.")
	test.expect(panel.vertical_view != null and panel.vertical_view.band_items.size() == 1, "Vertical view dynamically generates exactly 1 band for custom catalog.")

	if root != null and panel.get_parent() == root:
		root.remove_child(panel)
	panel.free()

	# 10. Demo scene instantiation test
	var demo_scene := load("res://night/ui/spectrum_codex/scenes/spectrum_codex_demo.tscn") as PackedScene
	test.expect(demo_scene != null, "SpectrumCodexDemo scene loads successfully.")
	var demo := demo_scene.instantiate() as SpectrumCodexDemo
	test.expect(demo != null, "SpectrumCodexDemo instantiates cleanly.")
	if root != null:
		root.add_child(demo)
		demo._on_unlock_test_func()
		demo._on_unlock_test_rec()
		demo._on_switch_mode()
		demo._on_focus_sample()
		root.remove_child(demo)
	demo.free()

	# 11. SpectrumAnalyzer main/secondary function and unlock state integration
	var analyzer := SpectrumAnalyzer.new()
	var analyzer_title_label := Label.new()
	analyzer.add_child(analyzer_title_label)
	if root != null:
		root.add_child(analyzer)
	analyzer.title_label = analyzer_title_label
	analyzer.setup(catalog_res, unlock_state_res)

	# Empty prediction
	analyzer.set_prediction({})
	test.expect(analyzer_title_label.text.contains("加入材料"), "Empty prediction shows initial guidance.")

	# Unlocked function (func_hemostasis at 0.05)
	analyzer.set_prediction({"mixed_x": 0.05, "failed": false})
	test.expect(analyzer_title_label.text.contains("主功能：止血") and analyzer_title_label.text.contains("副功能：止血"), "Unlocked function displays primary and secondary tags.")

	# Locked function (func_vigor_boost at 0.19)
	analyzer.set_prediction({"mixed_x": 0.19, "failed": false})
	test.expect(analyzer_title_label.text.contains("装瓶后显示"), "Locked function shows '装瓶后显示' before bottling.")

	# Unlock the function and verify dynamic refresh
	unlock_state_res.unlock_function(&"func_vigor_boost")
	test.expect(analyzer_title_label.text.contains("主功能：活化") and analyzer_title_label.text.contains("副功能：体力"), "Unlocking function dynamically refreshes analyzer title.")

	if root != null and analyzer.get_parent() == root:
		root.remove_child(analyzer)
	analyzer.free()

	# 12. ProductionPanel SpectrumFrame effect display and unlock state integration
	var prod_panel_scene := load("res://night/alchemy/production/production_panel.tscn") as PackedScene
	var prod_panel := prod_panel_scene.instantiate() as ProductionPanel
	if root != null:
		root.add_child(prod_panel)
	prod_panel.catalog = catalog_res
	prod_panel.unlock_state = unlock_state_res

	# Initially empty
	test.expect_equal(prod_panel.spectrum_label.text, "等待加工结果", "SpectrumFrame shows waiting state when empty.")

	# Simulate ground powder with unlocked spectrum (0.05)
	var powder_unlocked := PowderInstanceData.new()
	powder_unlocked.spectrum_x = 0.05
	prod_panel.ground_powder = powder_unlocked
	prod_panel._refresh_color()
	test.expect(prod_panel.spectrum_label.text.contains("功效：止血、循环"), "Unlocked spectrum shows primary effect name in SpectrumFrame.")

	# Simulate ground powder with locked spectrum (0.81, func_dispel is locked)
	var powder_locked := PowderInstanceData.new()
	powder_locked.spectrum_x = 0.81
	prod_panel.ground_powder = powder_locked
	prod_panel._refresh_color()
	test.expect(prod_panel.spectrum_label.text.contains("未知功效"), "Locked spectrum shows '未知功效' in SpectrumFrame.")

	# Unlock func_dispel and verify refresh
	unlock_state_res.unlock_function(&"func_dispel")
	test.expect(prod_panel.spectrum_label.text.contains("功效：净化、驱邪"), "Unlocking function updates SpectrumFrame to show unlocked effect.")

	if root != null and prod_panel.get_parent() == root:
		root.remove_child(prod_panel)
	prod_panel.free()

