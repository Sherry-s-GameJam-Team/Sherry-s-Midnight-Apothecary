extends RefCounted

const ALCHEMY_SCENE := preload("res://night/alchemy/alchemy_runtime.tscn")
const HERB_ID := &"herdsmans_loaf_bush"
const STARDUST_HERB_ID := &"stardust_puffy_lion"
const GRAIL_LILY_ID := &"grail_lily"
const DEW_FLASK_HERB_ID := &"dew_flask_herb"
const OLD_MANS_NOOSE_ID := &"old_mans_noose"
const PRAISE_STAR_MAPLE_ID := &"praise_star_maple"


static func run(test: TestSupport) -> void:
	var runtime := ALCHEMY_SCENE.instantiate() as AlchemyRuntime
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child(runtime)
	var player := PlayerData.new()
	player.inventory = {HERB_ID: 3, STARDUST_HERB_ID: 2, GRAIL_LILY_ID: 1, DEW_FLASK_HERB_ID: 2, OLD_MANS_NOOSE_ID: 1, PRAISE_STAR_MAPLE_ID: 1}
	var result := NightResult.new()
	runtime.setup(player, result, 4)
	var panel := runtime.production_panel
	var board := panel.process_board
	var herb := runtime.ingredient_by_id(HERB_ID)
	var stardust_herb := runtime.ingredient_by_id(STARDUST_HERB_ID)
	var grail_lily := runtime.ingredient_by_id(GRAIL_LILY_ID)
	var dew_flask_herb := runtime.ingredient_by_id(DEW_FLASK_HERB_ID)
	var old_mans_noose := runtime.ingredient_by_id(OLD_MANS_NOOSE_ID)
	var praise_star_maple := runtime.ingredient_by_id(PRAISE_STAR_MAPLE_ID)

	test.expect(runtime.ingredients.size() >= 6, "The ingredient library contains all six formally processed plants.")
	test.expect(herb != null and herb.id == HERB_ID, "Herdsman's Loaf-Bush is the registered formal herb.")
	test.expect(stardust_herb != null and stardust_herb.id == STARDUST_HERB_ID, "Stardust Puffy-Lion is registered as the second formal herb.")
	test.expect_equal(stardust_herb.display_name, "星屑蒲公英", "The second herb preserves its Chinese name.")
	test.expect_equal(stardust_herb.english_name, "Stardust Puffy-Lion", "The second herb preserves the requested folk name.")
	test.expect(stardust_herb.lore.contains("满月月光") and stardust_herb.lore.contains("光线吸引"), "The second herb preserves its moonlight-seeking lore.")
	test.expect(stardust_herb.icon != null and stardust_herb.preview_texture != null, "Stardust Puffy-Lion owns assembled shelf and preview artwork.")
	test.expect_equal(stardust_herb.reference_canvas_size, Vector2i(4096, 4096), "Stardust piece assembly uses the manifest canvas.")
	test.expect_equal(stardust_herb.production_layers.size(), 2, "Stardust Puffy-Lion has crown and foliage color layers.")
	test.expect_equal(stardust_herb.production_layers[0].pieces.size(), 1, "The luminous crown remains one detachable flower-head piece.")
	test.expect_equal(stardust_herb.production_layers[1].pieces.size(), 12, "All twelve foreground and background foliage pieces are processed.")
	test.expect_equal(stardust_herb.production_layers[0].pieces[0].source_rect, Rect2i(1270, 571, 1573, 1504), "The crown source rectangle is baked from the Stardust manifest.")
	test.expect_equal(stardust_herb.production_layers[1].pieces[11].source_rect, Rect2i(2608, 2231, 984, 1862), "The final foliage source rectangle is baked from the Stardust manifest.")
	var stardust_pieces := ProductionRuntimeTypes.create_piece_set(stardust_herb, &"stardust_test")
	test.expect_equal(stardust_pieces.size(), 13, "Stardust Puffy-Lion reconstructs from all thirteen processed pieces.")
	var stardust_assembly := HerbAssemblyView.new()
	stardust_assembly.size = Vector2(320.0, 320.0)
	scene_tree.root.add_child(stardust_assembly)
	stardust_assembly.setup(stardust_herb, stardust_pieces)
	test.expect_equal(stardust_assembly.get_child_count(), 13, "The assembled Stardust preview draws every processed texture at its manifest coordinates.")
	stardust_assembly.free()
	test.expect(grail_lily != null and grail_lily.id == GRAIL_LILY_ID, "Grail-Lily is registered as the third formal herb.")
	test.expect_equal(grail_lily.display_name, "圣杯百合", "Grail-Lily preserves its Chinese name.")
	test.expect_equal(grail_lily.english_name, "Grail-Lily", "Grail-Lily preserves its English name.")
	test.expect(grail_lily.lore.contains("寻找圣杯的骑士") and grail_lily.lore.contains("修道院的内庭"), "Grail-Lily preserves the requested knightly lore.")
	test.expect_equal(grail_lily.production_layers.size(), 2, "Grail-Lily has flower and foliage layers.")
	test.expect_equal(grail_lily.production_layers[0].pieces.size(), 1, "The quality-bearing flower remains one detachable piece.")
	test.expect_equal(grail_lily.production_layers[1].pieces.size(), 4, "All four supplied leaf groups are detachable pieces.")
	var grail_pieces := ProductionRuntimeTypes.create_piece_set(grail_lily, &"grail_test")
	test.expect_equal(grail_pieces.size(), 5, "Grail-Lily reconstructs from all five decomposition pieces.")
	test.expect_float_close(grail_pieces[0].quality, 1.485, 0.001, "The flower piece receives the requested high-quality multiplier.")
	test.expect(grail_pieces[0].quality > grail_pieces[1].quality, "Grinding the flower contributes more potion quality than grinding foliage.")
	test.expect(grail_lily.production_layers[0].pieces[0].texture.get_image().get_pixel(0, 0).a < 0.1, "The extracted flower sprite has transparent padding for alpha hit testing.")
	var grail_assembly := HerbAssemblyView.new()
	grail_assembly.size = Vector2(320.0, 320.0)
	scene_tree.root.add_child(grail_assembly)
	grail_assembly.setup(grail_lily, grail_pieces)
	test.expect_equal(grail_assembly.get_child_count(), 5, "The generic assembly view draws every Grail-Lily piece.")
	grail_assembly.free()
	test.expect(dew_flask_herb != null and dew_flask_herb.id == DEW_FLASK_HERB_ID, "Dew-Flask Herb is registered as a formal herb.")
	test.expect_equal(dew_flask_herb.display_name, "露水水囊草", "Dew-Flask Herb preserves its Chinese name.")
	test.expect_equal(dew_flask_herb.english_name, "Dew-Flask Herb", "Dew-Flask Herb preserves its English name.")
	test.expect(dew_flask_herb.lore.contains("清晨的留客饮") and dew_flask_herb.lore.contains("次日清晨"), "Dew-Flask Herb preserves its traveller and regrowth folklore.")
	test.expect(dew_flask_herb.icon != null and dew_flask_herb.preview_texture != null, "Dew-Flask Herb owns assembled shelf and preview artwork.")
	test.expect_equal(dew_flask_herb.reference_canvas_size, Vector2i(4096, 4096), "Dew-Flask assembly uses the supplied reference canvas.")
	test.expect_equal(dew_flask_herb.production_layers.size(), 2, "Dew-Flask Herb has water and foliage layers.")
	test.expect_equal(dew_flask_herb.production_layers[0].pieces.size(), 1, "The floating blue water flask remains one detachable piece.")
	test.expect_equal(dew_flask_herb.production_layers[1].pieces.size(), 4, "All four supplied foliage groups remain detachable pieces.")
	test.expect_equal(dew_flask_herb.production_layers[0].pieces[0].source_rect, Rect2i(1652, 70, 858, 938), "The water-flask source rectangle is baked from the supplied split image.")
	test.expect_equal(dew_flask_herb.production_layers[1].pieces[3].source_rect, Rect2i(2030, 1160, 1748, 1350), "The final foliage source rectangle is baked from the supplied split image.")
	var dew_flask_pieces := ProductionRuntimeTypes.create_piece_set(dew_flask_herb, &"dew_flask_test")
	test.expect_equal(dew_flask_pieces.size(), 5, "Dew-Flask Herb reconstructs from all five supplied decomposition pieces.")
	var original_panel_pieces := panel.pieces
	panel.pieces = dew_flask_pieces
	dew_flask_pieces[0].state = ProductionRuntimeTypes.HerbPieceRuntime.State.GROUND
	test.expect_equal(panel._special_potion_for_ground_pieces(), &"purification_potion", "Grinding only the blue dew marks powder for the dedicated purification recipe.")
	dew_flask_pieces[1].state = ProductionRuntimeTypes.HerbPieceRuntime.State.GROUND
	test.expect_equal(panel._special_potion_for_ground_pieces(), &"", "Adding foliage removes the dedicated purification marker.")
	for dew_piece: ProductionRuntimeTypes.HerbPieceRuntime in dew_flask_pieces:
		dew_piece.state = ProductionRuntimeTypes.HerbPieceRuntime.State.ATTACHED
	panel.pieces = original_panel_pieces
	test.expect(dew_flask_pieces[0].quality > dew_flask_pieces[1].quality, "The pure floating water contributes more quality than ordinary foliage.")
	test.expect(dew_flask_herb.production_layers[0].pieces[0].texture.get_image().get_pixel(0, 0).a < 0.1, "The extracted water-flask sprite keeps transparent padding for alpha hit testing.")
	var dew_flask_assembly := HerbAssemblyView.new()
	dew_flask_assembly.size = Vector2(320.0, 320.0)
	scene_tree.root.add_child(dew_flask_assembly)
	dew_flask_assembly.setup(dew_flask_herb, dew_flask_pieces)
	test.expect_equal(dew_flask_assembly.get_child_count(), 5, "The generic assembly view draws every Dew-Flask piece.")
	dew_flask_assembly.free()
	test.expect(old_mans_noose != null and old_mans_noose.id == OLD_MANS_NOOSE_ID, "Old Man's Noose is registered as a formal herb.")
	test.expect_equal(old_mans_noose.display_name, "绞索老汉", "Old Man's Noose preserves its Chinese folk name.")
	test.expect_equal(old_mans_noose.english_name, "Old Man’s Noose", "Old Man's Noose preserves its English folk name.")
	test.expect(old_mans_noose.lore.contains("迷路的老鬼") and old_mans_noose.description.contains("凝血"), "Old Man's Noose preserves its ghost-rope folklore and haemostatic use.")
	test.expect_equal(old_mans_noose.reference_canvas_size, Vector2i(4096, 4096), "Old Man's Noose uses the standardized processing canvas.")
	test.expect_equal(old_mans_noose.production_layers.size(), 2, "Old Man's Noose separates host waste from medicinal thalli.")
	test.expect_equal(old_mans_noose.production_layers[0].pieces.size(), 1, "The host branch remains one non-grindable waste piece.")
	test.expect(not old_mans_noose.production_layers[0].pieces[0].grindable, "The attached branch cannot enter the grinder.")
	test.expect_equal(old_mans_noose.production_layers[1].pieces.size(), 11, "All eleven hanging thalli are detachable and grindable.")
	var noose_pieces := ProductionRuntimeTypes.create_piece_set(old_mans_noose, &"old_mans_noose_test")
	test.expect_equal(noose_pieces.size(), 12, "Old Man's Noose reconstructs from the host and eleven thalli.")
	var noose_assembly := HerbAssemblyView.new()
	noose_assembly.size = Vector2(320.0, 320.0)
	scene_tree.root.add_child(noose_assembly)
	noose_assembly.setup(old_mans_noose, noose_pieces)
	test.expect_equal(noose_assembly.get_child_count(), 12, "The generic assembly view reconstructs every Old Man's Noose piece.")
	noose_assembly.free()
	test.expect(praise_star_maple != null and praise_star_maple.id == PRAISE_STAR_MAPLE_ID, "Praise-Star Maple is registered as a formal tree ingredient.")
	test.expect_equal(praise_star_maple.display_name, "礼赞五角槭", "Praise-Star Maple preserves its Chinese name.")
	test.expect_equal(praise_star_maple.english_name, "Praise-Star Maple", "Praise-Star Maple preserves its English name.")
	test.expect(praise_star_maple.lore.contains("大地母亲打好的包装") and praise_star_maple.lore.contains("教堂门口祈福"), "Praise-Star Maple preserves its harvest-festival folklore.")
	test.expect(praise_star_maple.description.contains("粗油灯") and praise_star_maple.description.contains("浓汤"), "Praise-Star Maple preserves both recorded fruit uses.")
	test.expect(praise_star_maple.icon != null and praise_star_maple.preview_texture != null, "Praise-Star Maple owns full-tree shelf and compendium artwork.")
	test.expect_equal(praise_star_maple.reference_canvas_size, Vector2i(4096, 4096), "Praise-Star fruit assembly uses the supplied reference canvas.")
	test.expect_equal(praise_star_maple.production_layers.size(), 1, "Only the fruit layer is processed for the tree ingredient.")
	test.expect_equal(praise_star_maple.production_layers[0].pieces.size(), 9, "Only the nine complete tied star-fruits become processing pieces.")
	test.expect_equal(praise_star_maple.production_layers[0].pieces[0].source_rect, Rect2i(1592, 255, 153, 193), "The first tied fruit retains its padded source coordinates.")
	test.expect_equal(praise_star_maple.production_layers[0].pieces[8].source_rect, Rect2i(2265, 2375, 211, 242), "The ninth tied fruit retains its padded source coordinates.")
	var praise_star_pieces := ProductionRuntimeTypes.create_piece_set(praise_star_maple, &"praise_star_test")
	test.expect_equal(praise_star_pieces.size(), 9, "Praise-Star Maple reconstructs from fruit pieces only, without trunk or foliage.")
	var praise_star_assembly := HerbAssemblyView.new()
	praise_star_assembly.size = Vector2(320.0, 320.0)
	scene_tree.root.add_child(praise_star_assembly)
	praise_star_assembly.setup(praise_star_maple, praise_star_pieces)
	test.expect_equal(praise_star_assembly.get_child_count(), 9, "The assembly view draws all nine tied fruits and no tree artwork.")
	praise_star_assembly.free()
	test.expect(runtime.ingredient_by_id(&"moon_mint") == null, "Temporary placeholder herbs are absent from the runtime library.")
	test.expect_equal(herb.display_name, "牧人块树", "The formal Chinese herb name is preserved.")
	test.expect_equal(herb.english_name, "Herdsman’s Loaf-Bush", "The formal English herb name is preserved.")
	test.expect(herb.icon != null and herb.preview_texture != null, "The herb owns dedicated shelf and preview artwork.")
	test.expect_equal(herb.reference_canvas_size, Vector2i(4096, 4096), "Piece assembly uses the manifest reference canvas.")
	test.expect_equal(herb.production_layers.size(), 2, "The herb has fruit and foliage production layers.")
	test.expect_equal(herb.production_layers[0].pieces.size(), 11, "The fruit layer contains eleven formal pieces.")
	test.expect_equal(herb.production_layers[1].pieces.size(), 6, "The foliage layer contains six formal pieces.")
	test.expect_equal(herb.production_layers[0].pieces[0].source_rect, Rect2i(1585, 1603, 295, 287), "Fruit source_rect is baked from the split manifest.")
	test.expect_equal(herb.production_layers[1].pieces[5].source_rect, Rect2i(2329, 2107, 1232, 1135), "Foliage source_rect is baked from the split manifest.")

	test.expect_equal(panel.pack_delay_seconds, 3.0, "Production packaging keeps the required three-second display delay.")
	test.expect_equal(panel.herb_grid.columns, 4, "The production inventory follows the artwork's four-column layout.")
	test.expect_equal(panel.herb_grid.get_child_count(), ProductionPanel.HERB_PAGE_SIZE, "The herb artwork always contains exactly its twelve 4 × 3 slots.")
	var shelf_cards: Array[Node] = panel.herb_grid.get_children().filter(func(child: Node) -> bool: return child is HerbCard)
	test.expect(shelf_cards.size() >= 6, "All six formal plants appear in the herb shelf.")
	var herb_card := shelf_cards.filter(func(card: HerbCard) -> bool: return card.ingredient_data.id == HERB_ID)[0] as HerbCard
	var stardust_card := shelf_cards.filter(func(card: HerbCard) -> bool: return card.ingredient_data.id == STARDUST_HERB_ID)[0] as HerbCard
	var grail_card := shelf_cards.filter(func(card: HerbCard) -> bool: return card.ingredient_data.id == GRAIL_LILY_ID)[0] as HerbCard
	var dew_flask_card := shelf_cards.filter(func(card: HerbCard) -> bool: return card.ingredient_data.id == DEW_FLASK_HERB_ID)[0] as HerbCard
	var old_mans_noose_card := shelf_cards.filter(func(card: HerbCard) -> bool: return card.ingredient_data.id == OLD_MANS_NOOSE_ID)[0] as HerbCard
	var praise_star_maple_card := shelf_cards.filter(func(card: HerbCard) -> bool: return card.ingredient_data.id == PRAISE_STAR_MAPLE_ID)[0] as HerbCard
	test.expect_equal(herb_card.ingredient_data.id, HERB_ID, "The only shelf card belongs to Herdsman's Loaf-Bush.")
	test.expect_equal(herb_card.available, 3, "The shelf card shows the current available quantity.")
	test.expect(herb_card.compact_icon == herb.icon, "The shelf card uses the herb's dedicated thumbnail.")
	test.expect_equal((herb_card.get_node("Content/NameLabel") as Label).text, "牧人块树", "The compact slot visibly includes the herb name.")
	test.expect_equal((herb_card.get_node("Content/CountLabel") as Label).text, "3", "Quantity is displayed as a bare number over the black dot.")
	test.expect(herb_card.tooltip_text.contains("Herdsman’s Loaf-Bush"), "The tooltip includes the English name.")
	test.expect_equal(stardust_card.available, 2, "The Stardust shelf card shows its own inventory count.")
	test.expect(stardust_card.compact_icon == stardust_herb.icon, "The Stardust shelf card uses its assembled thumbnail.")
	test.expect_equal((stardust_card.get_node("Content/NameLabel") as Label).text, "星屑蒲公英", "The Stardust shelf card visibly includes its Chinese name.")
	test.expect_equal(grail_card.available, 1, "The Grail-Lily shelf card shows its own inventory count.")
	test.expect(grail_card.compact_icon == grail_lily.icon, "The Grail-Lily shelf card uses its extracted transparent thumbnail.")
	test.expect_equal((grail_card.get_node("Content/NameLabel") as Label).text, "圣杯百合", "The third shelf slot visibly includes Grail-Lily's Chinese name.")
	test.expect_equal(dew_flask_card.available, 2, "The Dew-Flask shelf card shows its own inventory count.")
	test.expect(dew_flask_card.compact_icon == dew_flask_herb.icon, "The Dew-Flask shelf card uses its assembled thumbnail.")
	test.expect_equal((dew_flask_card.get_node("Content/NameLabel") as Label).text, "露水水囊草", "The Dew-Flask shelf slot visibly includes its Chinese name.")
	test.expect_equal(old_mans_noose_card.available, 1, "The Old Man's Noose shelf card shows its inventory count.")
	test.expect_equal((old_mans_noose_card.get_node("Content/NameLabel") as Label).text, "绞索老汉", "The fifth shelf slot visibly includes Old Man's Noose.")
	test.expect_equal(praise_star_maple_card.available, 1, "The Praise-Star Maple shelf card shows its inventory count.")
	test.expect(praise_star_maple_card.compact_icon == praise_star_maple.icon, "The Praise-Star shelf card uses the whole-tree thumbnail rather than a fruit crop.")
	test.expect_equal((praise_star_maple_card.get_node("Content/NameLabel") as Label).text, "礼赞五角槭", "The Praise-Star shelf slot visibly includes its Chinese name.")
	test.expect_equal(panel.herb_grid.get_parent(), panel.get_node("HerbInventoryArt"), "The herb grid follows the inventory artwork at every viewport aspect ratio.")
	player.inventory[HERB_ID] = 7
	panel.refresh_inventory()
	test.expect_equal(panel.herb_grid.get_child(0), herb_card, "Inventory refresh keeps the existing card and its grid position stable.")
	test.expect_equal(herb_card.available, 7, "Inventory refresh updates the card's available quantity in place.")
	test.expect_equal((herb_card.get_node("Content/CountLabel") as Label).text, "7", "The visible badge immediately reflects refreshed inventory.")
	player.inventory[HERB_ID] = 3
	panel.refresh_inventory()
	var herb_drag: Dictionary = herb_card._get_drag_data(Vector2.ZERO)
	test.expect_equal(herb_drag.get("ingredient_id"), HERB_ID, "The shelf produces the standard herb drag payload.")

	test.expect(not board._can_drop_data(Vector2.ZERO, herb_drag), "Whole herbs are rejected by the artwork side trays.")
	test.expect(board._can_drop_data(board.size * 0.5, herb_drag), "The center workbench accepts the formal herb payload.")
	var drop_surface: Control = panel.get_node("HerbDropSurface") as Control
	test.expect(drop_surface != null and drop_surface.has_method("_can_drop_data") and drop_surface.has_method("_drop_data"), "A top-level surface delegates native herb drag-and-drop to ProcessBoard.")
	test.expect_equal(drop_surface.mouse_filter, Control.MOUSE_FILTER_STOP, "The top-level herb surface participates in native GUI drag targeting.")
	test.expect_equal(runtime.unified_powder_shelf.mouse_filter, Control.MOUSE_FILTER_IGNORE, "The powder shelf's transparent root cannot obstruct the production board.")
	test.expect_equal(runtime.unified_powder_shelf.item_grid.mouse_filter, Control.MOUSE_FILTER_IGNORE, "Empty powder-grid space cannot obstruct a native herb drop.")
	var board_center_global := board.get_global_control_rect(board.board_zone).get_center()
	var surface_center: Vector2 = drop_surface.get_global_transform().affine_inverse() * board_center_global
	test.expect(bool(drop_surface.call("_can_drop_data", surface_center, herb_drag)), "The top-level drop surface accepts the herb over the center board.")
	var board_zone_rect := board.get_global_control_rect(board.board_zone)
	var drop_surface_rect := board.get_global_control_rect(drop_surface)
	test.expect(drop_surface_rect.position.is_equal_approx(board_zone_rect.position) and drop_surface_rect.size.is_equal_approx(board_zone_rect.size), "The native herb drop surface exactly follows the full visible board rectangle.")
	var zones_rect := board.get_global_control_rect(board.zones)
	test.expect(is_equal_approx(board_zone_rect.position.y, zones_rect.position.y) and is_equal_approx(board_zone_rect.end.y, zones_rect.end.y), "The board drop mask spans the complete visual workspace height.")
	for vertical_ratio: float in [0.05, 0.5, 0.95]:
		var global_probe := Vector2(board_zone_rect.get_center().x, lerpf(board_zone_rect.position.y, board_zone_rect.end.y, vertical_ratio))
		var surface_probe: Vector2 = drop_surface.get_global_transform().affine_inverse() * global_probe
		test.expect(bool(drop_surface.call("_can_drop_data", surface_probe, herb_drag)), "The herb drop surface accepts the full board height at %.0f%%." % (vertical_ratio * 100.0))
	test.expect(bool(drop_surface.call("_can_drop_data", Vector2(-9999.0, -9999.0), herb_drag)), "Once the exact top-level surface is hit, callback-local coordinates cannot reject a valid herb payload.")
	drop_surface.call("_drop_data", surface_center, herb_drag)
	test.expect_equal(runtime.available_count(HERB_ID), 2, "Dragging reserves exactly one source plant.")
	test.expect_equal(player.inventory[HERB_ID], 3, "Reservation never mutates PlayerData directly.")
	test.expect_equal(result.spent_ingredients.size(), 0, "Reservation does not write NightResult spending.")
	test.expect_equal(panel.pieces.size(), 17, "The intact plant is composed from all seventeen pieces.")
	var source_instance_id := panel.current_source_instance_id
	var all_attached := source_instance_id != &""
	for piece: ProductionRuntimeTypes.HerbPieceRuntime in panel.pieces:
		all_attached = all_attached and piece.state == ProductionRuntimeTypes.HerbPieceRuntime.State.ATTACHED
		test.expect_equal(piece.source_instance_id, source_instance_id, "All pieces from one plant share one source_instance_id.")
	test.expect(all_attached, "All seventeen pieces begin in ATTACHED state.")
	test.expect_equal(board.board_items.get_child_count(), 1, "The intact workbench contains one assembly view.")
	var assembly := board.board_items.get_child(0) as HerbAssemblyView
	test.expect(assembly != null and assembly.get_child_count() == 17, "The intact herb is reconstructed from seventeen source textures.")

	test.expect(panel.separate_herb(), "The intact plant can be detached.")
	test.expect_equal(panel.spectrum_label.text, "等待加工结果", "Detaching alone does not publish a current spectrum value.")
	test.expect_equal(board.get_piece_views().size(), 17, "Every detached piece gets one persistent free-drag view.")
	var fruit_piece := panel.pieces[0]
	var second_piece := panel.pieces[1]
	var foliage_piece := panel.pieces[11]
	var waste_piece := panel.pieces[2]
	var fruit_view := board.get_piece_view(fruit_piece)
	var second_view := board.get_piece_view(second_piece)
	var foliage_view := board.get_piece_view(foliage_piece)
	var waste_view := board.get_piece_view(waste_piece)

	test.expect(fruit_view != null and fruit_view.get_parent() == board.piece_drag_layer, "Pieces live in the overlay PieceDragLayer.")
	test.expect(fruit_view.get_class() == "Control" and not fruit_view.has_theme_stylebox_override("panel"), "A piece is a transparent Control without a card or panel style.")
	test.expect(fruit_view.artwork.texture == fruit_piece.data.texture, "The piece view draws its transparent PNG directly.")
	test.expect(fruit_view.hover_outline.material != second_view.hover_outline.material, "Every piece owns an independent outline material.")
	test.expect_equal(fruit_view._outline_material.get_shader_parameter("outline_enabled"), false, "Outline rendering is disabled at rest.")
	var alpha_points := _find_alpha_points(fruit_view)
	test.expect(alpha_points.has("opaque") and fruit_view._has_point(alpha_points.get("opaque", Vector2.ZERO)), "Opaque artwork pixels receive pointer input.")
	test.expect(alpha_points.has("transparent") and not fruit_view._has_point(alpha_points.get("transparent", Vector2.ZERO)), "Transparent pixels inside the texture bounds do not receive pointer input.")
	fruit_view.set_outline_enabled(true)
	test.expect_equal(fruit_view._outline_material.get_shader_parameter("outline_enabled"), true, "Hover/drag can enable the alpha-contour shader.")
	fruit_view.set_outline_enabled(false)
	var magnet := board.magnet_controller
	test.expect(magnet != null, "The production board owns one generic herb magnet controller.")
	test.expect(magnet.is_processing_input(), "The magnet explicitly receives global mouse input instead of relying on a partial GUI hit area.")
	test.expect_equal(board.mouse_filter, Control.MOUSE_FILTER_IGNORE, "The displaced outer board never creates a second magnet input surface.")
	test.expect_equal(board.zones.mouse_filter, Control.MOUSE_FILTER_IGNORE, "Nested visual zones cannot recreate a partial native drop surface.")
	test.expect_float_close(magnet.candidate_radius, 72.0, 0.001, "The magnet exposes the requested candidate radius.")
	test.expect_float_close(magnet.acquire_radius, 42.0, 0.001, "The magnet exposes the requested acquire radius.")
	test.expect_float_close(magnet.candidate_hold_time, 0.05, 0.001, "Candidate stability uses the requested short hold time.")
	test.expect_float_close(magnet.snap_duration, 0.08, 0.001, "Pickup snapping uses the requested short duration.")
	test.expect_equal(fruit_view.mouse_filter, Control.MOUSE_FILTER_IGNORE, "Piece controls do not steal input from empty-space magnet searching.")
	var movement_bounds := board.get_movement_rect()
	magnet.set_grab_mode(HerbMagnetController.GrabMode.MULTI_MAGNET)
	var upper_board_point := Vector2(movement_bounds.get_center().x, movement_bounds.position.y + movement_bounds.size.y * 0.1)
	var upper_press := InputEventMouseButton.new()
	upper_press.button_index = MOUSE_BUTTON_LEFT
	upper_press.pressed = true
	upper_press.global_position = board.get_canvas_transform() * upper_board_point
	upper_press.position = upper_press.global_position
	magnet._input(upper_press)
	test.expect_equal(magnet.state, HerbMagnetController.MagnetState.SEARCHING, "The upper tenth of the visible movement bounds accepts magnetic left-button input.")
	var upper_release := InputEventMouseButton.new()
	upper_release.button_index = MOUSE_BUTTON_LEFT
	upper_release.pressed = false
	upper_release.global_position = upper_press.global_position
	upper_release.position = upper_press.position
	magnet._input(upper_release)
	magnet.set_grab_mode(HerbMagnetController.GrabMode.SINGLE)
	var empty_search_point := movement_bounds.position + Vector2(2.0, 2.0)
	test.expect(magnet.begin_search(empty_search_point), "Holding left mouse from an empty workbench point enters magnet searching.")
	test.expect_equal(magnet.state, HerbMagnetController.MagnetState.SEARCHING, "Empty-space press remains SEARCHING without a target.")
	magnet.release_piece()
	test.expect_equal(magnet.state, HerbMagnetController.MagnetState.IDLE, "Releasing an empty search returns to IDLE without moving a piece.")
	test.expect(not magnet.begin_search(panel.herb_grid.get_global_rect().get_center()), "The herb shelf cannot start a magnet search.")
	test.expect(not magnet.begin_search(panel.drag_button.get_global_rect().get_center()), "Tool buttons cannot start a magnet search.")
	for magnet_view: ProductionPieceView in board.get_piece_views():
		magnet_view.magnet_pickup_blocked = magnet_view != fruit_view
	var lower_edge_original_position := fruit_view.global_position
	var opaque_local: Vector2 = alpha_points.get("opaque", fruit_view.size * 0.5)
	var lower_edge_opaque_global: Vector2 = fruit_view.get_global_transform() * opaque_local
	fruit_view.global_position += Vector2(0.0, movement_bounds.end.y + 2.0 - lower_edge_opaque_global.y)
	lower_edge_opaque_global = fruit_view.get_global_transform() * opaque_local
	test.expect(not movement_bounds.has_point(lower_edge_opaque_global) and fruit_view.contains_global_point(lower_edge_opaque_global), "A visible opaque piece pixel can extend just below the rectangular movement mask.")
	var lower_edge_press := InputEventMouseButton.new()
	lower_edge_press.button_index = MOUSE_BUTTON_LEFT
	lower_edge_press.pressed = true
	test.expect(magnet.handle_global_pointer_input(lower_edge_press, lower_edge_opaque_global), "The lower visible piece edge remains draggable through its Alpha interaction mask.")
	magnet.cancel_current_grab()
	fruit_view.global_position = lower_edge_original_position
	fruit_piece.workspace_position = fruit_view.position
	fruit_piece.has_workspace_position = true
	var magnet_test_start := fruit_view.global_position
	var transparent_global: Vector2 = fruit_view.get_global_transform() * alpha_points.get("transparent", Vector2.ZERO)
	test.expect(not fruit_view.contains_global_point(transparent_global), "The magnet's public Alpha test rejects a transparent texture pixel.")
	test.expect(magnet.begin_search(transparent_global), "A press over transparent padding can begin searching without becoming a direct hit.")
	test.expect_equal(magnet.state, HerbMagnetController.MagnetState.SEARCHING, "Transparent padding does not trigger immediate pickup.")
	test.expect(magnet.candidate_piece == fruit_view, "The nearest effective piece becomes the stable search candidate.")
	test.expect_equal(fruit_view._outline_material.get_shader_parameter("outline_enabled"), true, "The search candidate receives a bright Alpha outline.")
	test.expect(fruit_view.scale.x > 1.0, "The search candidate receives the subtle requested enlargement.")
	magnet.advance(0.02)
	test.expect_equal(magnet.state, HerbMagnetController.MagnetState.SEARCHING, "A quick pass shorter than candidate_hold_time does not mis-grab.")
	magnet.advance(0.04)
	test.expect_equal(magnet.state, HerbMagnetController.MagnetState.SNAPPING, "Holding the same candidate inside acquire_radius begins snapping.")
	test.expect(fruit_view.global_position.is_equal_approx(magnet_test_start), "Starting a snap does not jump the piece to the pointer.")
	var snap_pointer := transparent_global + Vector2(8.0, 5.0)
	magnet.update_pointer(snap_pointer)
	test.expect(not fruit_view.global_position.is_equal_approx(magnet_test_start), "A moving pointer updates the snap target in real time.")
	var locked_during_snap := magnet.locked_piece
	magnet.update_pointer(second_view.get_global_content_rect().get_center())
	test.expect(magnet.locked_piece == locked_during_snap, "A selected piece cannot switch targets before mouse release.")
	magnet.advance(0.1)
	test.expect_equal(magnet.state, HerbMagnetController.MagnetState.DRAGGING, "Completed snapping enters stable pointer-following drag.")
	var waste_target := board.get_waste_detection_rect().get_center()
	magnet.update_pointer(waste_target)
	magnet.release_piece()
	test.expect_equal(fruit_piece.state, ProductionRuntimeTypes.HerbPieceRuntime.State.WASTE, "Magnet release classifies the piece geometry into WASTE.")
	var cancel_position := fruit_view.global_position
	var opaque_global: Vector2 = fruit_view.get_global_transform() * alpha_points.get("opaque", Vector2.ZERO)
	test.expect(fruit_view.contains_global_point(opaque_global), "The magnet's public Alpha test accepts an opaque texture pixel.")
	magnet.begin_search(opaque_global)
	test.expect_equal(magnet.state, HerbMagnetController.MagnetState.SNAPPING, "Direct opaque hits begin pickup immediately.")
	magnet.advance(0.1)
	magnet.update_pointer(board.get_global_control_rect(board.board_zone).get_center())
	var escape_event := InputEventKey.new()
	escape_event.pressed = true
	escape_event.keycode = KEY_ESCAPE
	magnet._input(escape_event)
	test.expect_equal(magnet.state, HerbMagnetController.MagnetState.IDLE, "Escape cancels an active magnetic drag.")
	test.expect(fruit_view.global_position.is_equal_approx(cancel_position), "Escape restores the pre-pickup visual position.")
	test.expect_equal(fruit_piece.state, ProductionRuntimeTypes.HerbPieceRuntime.State.WASTE, "Escape restores the pre-pickup region state.")
	opaque_global = fruit_view.get_global_transform() * alpha_points.get("opaque", Vector2.ZERO)
	magnet.begin_search(opaque_global)
	magnet.advance(0.1)
	magnet.update_pointer(board.get_global_control_rect(board.board_zone).get_center())
	var right_event := InputEventMouseButton.new()
	right_event.pressed = true
	right_event.button_index = MOUSE_BUTTON_RIGHT
	magnet._input(right_event)
	test.expect(fruit_view.global_position.is_equal_approx(cancel_position) and fruit_piece.state == ProductionRuntimeTypes.HerbPieceRuntime.State.WASTE, "Right click also cancels and restores position and state.")
	opaque_global = fruit_view.get_global_transform() * alpha_points.get("opaque", Vector2.ZERO)
	magnet.begin_search(opaque_global)
	magnet.advance(0.1)
	magnet.update_pointer(board.get_global_control_rect(board.board_zone).get_center())
	magnet.release_piece()
	test.expect_equal(fruit_piece.state, ProductionRuntimeTypes.HerbPieceRuntime.State.SEPARATED, "A waste piece can be magnetically returned to the workbench.")
	_center_view_at(board, fruit_view, board.get_grind_detection_rect().get_center())
	board._on_piece_drag_finished(fruit_view)
	test.expect_equal(fruit_piece.state, ProductionRuntimeTypes.HerbPieceRuntime.State.GRIND, "The test piece can enter the grind queue before magnetic recovery.")
	opaque_global = fruit_view.get_global_transform() * alpha_points.get("opaque", Vector2.ZERO)
	magnet.begin_search(opaque_global)
	magnet.advance(0.1)
	magnet.update_pointer(board.get_global_control_rect(board.board_zone).get_center())
	magnet.release_piece()
	test.expect_equal(fruit_piece.state, ProductionRuntimeTypes.HerbPieceRuntime.State.SEPARATED, "A grind-queued piece can be magnetically returned to the workbench.")
	board.move_piece_view(fruit_view, magnet_test_start)
	fruit_piece.state = ProductionRuntimeTypes.HerbPieceRuntime.State.SEPARATED
	fruit_view.refresh_state_visual()
	var priority_first_position := fruit_view.global_position
	var priority_second_position := second_view.global_position
	var priority_first_z := fruit_view.z_index
	var priority_second_z := second_view.z_index
	var shared_center := board.get_global_control_rect(board.board_zone).get_center()
	board.move_piece_view(fruit_view, shared_center - fruit_view.size * 0.5)
	board.move_piece_view(second_view, shared_center - second_view.size * 0.5)
	second_view.magnet_pickup_blocked = false
	fruit_view.z_index = 400
	second_view.z_index = 401
	var shared_transparent_point := _find_shared_transparent_point(fruit_view, second_view)
	test.expect(shared_transparent_point.x != INF, "Overlapping pieces expose a shared transparent point for deterministic candidate testing.")
	test.expect(magnet.find_best_candidate(shared_transparent_point) == second_view, "When distances are tied, the higher z-index piece wins magnet selection.")
	second_view.magnet_pickup_blocked = true
	test.expect(magnet.find_best_candidate(shared_transparent_point) == fruit_view, "A temporarily non-interruptible piece is excluded from magnet candidates.")
	second_view.magnet_pickup_blocked = false
	board.move_piece_view(fruit_view, priority_first_position)
	board.move_piece_view(second_view, priority_second_position)
	fruit_view.z_index = priority_first_z
	second_view.z_index = priority_second_z
	fruit_view.piece.stack_z = priority_first_z
	second_view.piece.stack_z = priority_second_z
	for magnet_view: ProductionPieceView in board.get_piece_views():
		magnet_view.magnet_pickup_blocked = false
	opaque_global = fruit_view.get_global_transform() * alpha_points.get("opaque", Vector2.ZERO)
	magnet.begin_search(opaque_global)
	magnet.advance(0.1)
	magnet.update_pointer(board.get_waste_detection_rect().get_center())
	panel.cancel_piece_drag()
	test.expect_equal(magnet.state, HerbMagnetController.MagnetState.IDLE, "Panel navigation cancellation safely ends a magnetic drag.")
	test.expect(fruit_view.global_position.is_equal_approx(priority_first_position), "Panel navigation restores the pickup-start position.")

	var original_position := fruit_view.global_position
	var grab_point := original_position + Vector2(12.0, 9.0)
	var old_z := fruit_view.z_index
	fruit_view._begin_drag_at(grab_point)
	fruit_view._update_drag_to(grab_point + Vector2(16.0, 7.0))
	test.expect(fruit_view.global_position.is_equal_approx(original_position + Vector2(16.0, 7.0)), "Direct dragging preserves the grab offset without jumping.")
	test.expect(fruit_view.z_index > old_z and fruit_view.piece.stack_z == fruit_view.z_index, "Dragging raises and persists the piece stacking order.")
	fruit_view._end_drag()
	test.expect(fruit_view.get_parent() == board.piece_drag_layer, "Dragging reuses the original view and never creates a drag preview.")

	var waste_visible := board.get_global_control_rect(board.waste_zone)
	var waste_detection := board.get_waste_detection_rect()
	var grind_visible := board.get_global_control_rect(board.grind_zone)
	var grind_detection := board.get_grind_detection_rect()
	test.expect_float_close(waste_detection.size.x - waste_visible.size.x, 70.0, 0.1, "Waste detection expands 35 px on both horizontal sides.")
	test.expect_float_close(grind_detection.size.y - grind_visible.size.y, 70.0, 0.1, "Grind detection expands 35 px on both vertical sides.")

	_center_view_at(board, waste_view, waste_detection.get_center())
	board._on_piece_drag_finished(waste_view)
	test.expect_equal(waste_piece.state, ProductionRuntimeTypes.HerbPieceRuntime.State.WASTE, "A piece becomes WASTE from its current global geometry.")
	_center_view_at(board, waste_view, grind_detection.get_center())
	board._on_piece_drag_finished(waste_view)
	test.expect_equal(waste_piece.state, ProductionRuntimeTypes.HerbPieceRuntime.State.GRIND, "A waste-marked piece remains draggable into GRIND.")
	_center_view_at(board, waste_view, board.get_global_control_rect(board.board_zone).get_center())
	board._on_piece_drag_finished(waste_view)
	test.expect_equal(waste_piece.state, ProductionRuntimeTypes.HerbPieceRuntime.State.SEPARATED, "A marked piece can return freely to the workbench.")

	fruit_view.rotation = 0.0
	var fruit_content_size := board.get_global_content_rect(fruit_view).size
	var partial_target := Rect2(
		Vector2(grind_detection.position.x - fruit_content_size.x * 0.70, grind_detection.get_center().y - fruit_content_size.y * 0.5),
		fruit_content_size
	)
	_place_content_rect(fruit_view, partial_target)
	test.expect_equal(board.classify_piece_region(fruit_view), ProcessBoard.PieceRegion.GRIND, "At least 25% overlap classifies a piece even when its center is outside.")

	var overlap_target := board.get_global_control_rect(board.board_zone).get_center()
	_center_view_at(board, fruit_view, overlap_target)
	_center_view_at(board, second_view, overlap_target)
	var first_overlap_position := fruit_view.global_position
	panel._refresh_board()
	test.expect(fruit_view.global_position.is_equal_approx(first_overlap_position), "Refreshing preserves free placement instead of applying a grid/list layout.")
	test.expect(board.get_global_content_rect(fruit_view).intersects(board.get_global_content_rect(second_view)), "Detached pieces may overlap one another.")

	var movement_rect := board.get_movement_rect()
	board._on_piece_drag_position_requested(second_view, movement_rect.position - Vector2(500.0, 500.0))
	var clamped_center := board.get_global_content_rect(second_view).get_center()
	test.expect(movement_rect.has_point(clamped_center) or clamped_center.is_equal_approx(movement_rect.position), "Piece centers are clamped to the global movement bounds.")

	_center_view_at(board, fruit_view, grind_detection.get_center())
	_center_view_at(board, foliage_view, grind_detection.get_center())
	_center_view_at(board, waste_view, waste_detection.get_center())
	fruit_piece.state = ProductionRuntimeTypes.HerbPieceRuntime.State.SEPARATED
	foliage_piece.state = ProductionRuntimeTypes.HerbPieceRuntime.State.SEPARATED
	waste_piece.state = ProductionRuntimeTypes.HerbPieceRuntime.State.SEPARATED
	test.expect_equal(panel.spectrum_label.text, "等待加工结果", "Moving pieces between workbench zones does not update the spectrum before grinding.")
	test.expect(panel.grind_selected_pieces(), "The grind action reclassifies current positions before processing.")
	test.expect_equal(fruit_piece.state, ProductionRuntimeTypes.HerbPieceRuntime.State.GROUND, "A spatially selected fruit is ground even when its prior state was stale.")
	test.expect_equal(waste_piece.state, ProductionRuntimeTypes.HerbPieceRuntime.State.WASTE, "Waste is marked but not discarded during grinding.")
	test.expect(panel.ground_powder != null and panel.ground_powder.source_instance_id == source_instance_id, "Powder retains the source plant instance.")
	var first_grind_spectrum := panel.ground_powder.spectrum_x
	var first_grind_amount := panel.ground_powder.amount
	var first_grind_label := panel.spectrum_label.text
	test.expect(first_grind_label.begins_with("当前色值"), "The current spectrum is first published after a successful grind.")
	test.expect(not panel.pack_powder(), "Powder cannot be packed while plant pieces remain on the workbench.")
	test.expect(panel.status_label.text.contains("案板上仍有植物部位"), "The blocked pack action explains that the workbench must be cleared.")
	test.expect_equal(waste_piece.state, ProductionRuntimeTypes.HerbPieceRuntime.State.WASTE, "A blocked pack attempt does not prematurely discard marked waste.")
	_center_view_at(board, second_view, grind_detection.get_center())
	board._on_piece_drag_finished(second_view)
	test.expect_equal(panel.spectrum_label.text, first_grind_label, "Moving another piece into the grinder does not preview a new spectrum.")
	for pending_view: ProductionPieceView in board.get_piece_views():
		if pending_view == second_view:
			continue
		_center_view_at(board, pending_view, waste_detection.get_center())
		board._on_piece_drag_finished(pending_view)
	test.expect(not panel.pack_powder(), "An unground piece waiting in the grinder also blocks packaging.")
	test.expect(panel.status_label.text.contains("研磨区仍有未研磨部位"), "The blocked pack action asks the player to finish the pending grind.")
	test.expect(panel.grind_selected_pieces(), "A second grind is allowed before packaging.")
	test.expect_equal(second_piece.state, ProductionRuntimeTypes.HerbPieceRuntime.State.GROUND, "The second batch is added to the existing powder.")
	test.expect(panel.ground_powder.amount > first_grind_amount, "Repeated grinding accumulates powder amount.")
	test.expect(not is_equal_approx(panel.ground_powder.spectrum_x, first_grind_spectrum), "The accumulated spectrum updates only after the second grind completes.")
	for remaining_view: ProductionPieceView in board.get_piece_views():
		_center_view_at(board, remaining_view, waste_detection.get_center())
		board._on_piece_drag_finished(remaining_view)
	test.expect(panel.pack_powder(), "Ground powder enters the packaging state.")
	test.expect_equal(waste_piece.state, ProductionRuntimeTypes.HerbPieceRuntime.State.DISCARDED, "Waste is formally discarded only when packaging commits the selection.")
	test.expect(board.get_piece_view(waste_piece) == null, "A formally discarded piece leaves the drag layer.")
	test.expect(panel.packing and panel.pack_timer.time_left > 2.9, "Packaging starts the real three-second display timer.")
	test.expect(panel.complete_pack_immediately(), "Packaged powder enters the shared shelf.")
	test.expect_equal(fruit_piece.state, ProductionRuntimeTypes.HerbPieceRuntime.State.SHELVED, "Packed pieces transition to SHELVED after commit.")
	test.expect_equal(runtime.powder_shelf_state.items.size(), 1, "The shared powder shelf receives the package.")
	var shelved_package := runtime.unified_powder_shelf.item_grid.get_child(0) as PowderItemView
	test.expect(shelved_package != null and shelved_package.paper_texture != null, "A shelved powder package retains the paper texture below the powder.")
	test.expect(shelved_package.get_node_or_null("Paper") is TextureRect, "The shelf package draws a persistent paper layer.")
	test.expect(shelved_package.get_node("Paper").get_index() < shelved_package.get_node("Powder").get_index(), "Paper is rendered below the tinted powder layer.")
	test.expect(not shelved_package.visible, "A new package waits at its source position instead of flashing in the destination slot.")
	var shelf_target_position := shelved_package.position
	var animation_start := Rect2(
		shelved_package.get_global_rect().position + Vector2(220.0, 120.0),
		shelved_package.get_global_rect().size * 1.8
	)
	runtime.unified_powder_shelf._start_placement_animation(shelved_package, animation_start)
	test.expect(shelved_package.visible and not shelved_package.position.is_equal_approx(shelf_target_position), "The package animation begins at the supplied processing-area position.")
	test.expect(shelved_package.scale.x > 1.0 and shelved_package.scale.y > 1.0, "The moving package starts at the processing preview's larger scale.")
	runtime.unified_powder_shelf.placement_tween.custom_step(runtime.unified_powder_shelf.placement_animation_seconds + 0.1)
	test.expect(shelved_package.position.is_equal_approx(shelf_target_position), "The package moves smoothly to its assigned shelf slot.")
	test.expect(shelved_package.scale.is_equal_approx(Vector2.ONE), "The package finishes at the shelf slot's normal scale.")
	test.expect_equal(result.spent_ingredients.get(HERB_ID), 1, "Seventeen pieces consume only one source plant.")

	panel._on_herb_dropped(HERB_ID)
	test.expect(panel.separate_herb(), "A new plant can begin another process.")
	var redo_piece := panel.pieces[0]
	var redo_view := board.get_piece_view(redo_piece)
	_center_view_at(board, redo_view, waste_detection.get_center())
	board._on_piece_drag_finished(redo_view)
	test.expect_equal(redo_piece.state, ProductionRuntimeTypes.HerbPieceRuntime.State.WASTE, "Redo test marks a piece as waste without deleting it.")
	runtime.horizontal_stage.position.x -= 40.0
	test.expect_equal(board.classify_piece_region(redo_view), ProcessBoard.PieceRegion.WASTE, "Horizontal panel movement preserves global region classification.")
	runtime.horizontal_stage.position.x += 40.0
	runtime.horizontal_stage.scale = Vector2(0.8, 0.8)
	test.expect_equal(board.classify_piece_region(redo_view), ProcessBoard.PieceRegion.WASTE, "UI scaling preserves global region classification.")
	runtime.horizontal_stage.scale = Vector2.ONE
	redo_view._begin_drag_at(redo_view.global_position + Vector2(5.0, 5.0))
	runtime.show_production_panel()
	test.expect(not redo_view.is_dragging, "Panel navigation cancels any active piece drag.")
	panel.redo_current_process()
	test.expect_equal(runtime.available_count(HERB_ID), 2, "Redo releases the uncommitted source plant, including waste-marked pieces.")
	test.expect_equal(result.spent_ingredients.get(HERB_ID), 1, "Redo does not permanently consume marked waste.")

	var powder_id := runtime.powder_shelf_state.items[0].source_instance_id
	test.expect(runtime.add_powder_to_cauldron(powder_id), "Brewing can take the processed powder from the shared shelf.")
	var spent_before_brew := int(result.spent_ingredients.get(HERB_ID, 0))
	runtime.heat_controller.cooling_rate = 0.0
	runtime.set_temperature(50.0)
	test.expect(not runtime.brew().is_empty(), "Processed powder starts the bellows distillation flow.")
	for pump_index in 6:
		runtime.pump_bellows()
	runtime.distillation_fill.stop_animation()
	runtime.distillation_fill.set_fill_progress(1.0)
	runtime._on_distillation_fill_animation_finished(1.0)
	runtime._on_bottling_confirmed(&"health", "")
	test.expect(not runtime.last_brewed_instance.is_empty(), "A filled distillation vessel commits a processed powder potion.")
	test.expect_equal(result.spent_ingredients.get(HERB_ID), spent_before_brew, "Brewing powder does not deduct its source plant twice.")
	player.apply_night_result(result)
	test.expect_equal(player.inventory[HERB_ID], 2, "Night settlement applies production consumption once.")
	var herdsman_available_before_mixed_batch := runtime.available_count(HERB_ID)
	var stardust_available_before_mixed_batch := runtime.available_count(STARDUST_HERB_ID)
	panel.refresh_inventory()
	var current_stardust_card := panel.herb_grid.get_children().filter(
		func(child: Node) -> bool:
			return child is HerbCard and (child as HerbCard).ingredient_data.id == STARDUST_HERB_ID
	)[0] as HerbCard
	var stardust_drag: Dictionary = current_stardust_card._get_drag_data(Vector2.ZERO)
	board._drop_data(board.size * 0.5, stardust_drag)
	test.expect(panel.current_herb == stardust_herb and panel.pieces.size() == 13, "Stardust Puffy-Lion can enter the real production board with all processed pieces.")
	test.expect_equal((board.board_items.get_child(0) as HerbAssemblyView).get_child_count(), 13, "The production board visibly reconstructs the second plant.")
	test.expect(panel.separate_herb() and board.get_piece_views().size() == 13, "All Stardust pieces detach into draggable production views.")
	var preserved_stardust_view := board.get_piece_views()[0]
	var preserved_stardust_position := preserved_stardust_view.position
	var current_herdsman_card := panel.herb_grid.get_children().filter(
		func(child: Node) -> bool:
			return child is HerbCard and (child as HerbCard).ingredient_data.id == HERB_ID
	)[0] as HerbCard
	var second_herb_drag: Dictionary = current_herdsman_card._get_drag_data(Vector2.ZERO)
	board._drop_data(board.size * 0.5, second_herb_drag)
	test.expect_equal(panel.source_herbs.size(), 2, "A second herb can be reserved while detached pieces remain on the workbench.")
	test.expect_equal(panel.pieces.size(), 30, "The production batch retains thirteen detached Stardust pieces plus seventeen new herb pieces.")
	test.expect_equal(board.get_piece_views().size(), 13, "Existing detached pieces remain independently draggable while the new herb is intact.")
	test.expect(preserved_stardust_view.position.is_equal_approx(preserved_stardust_position), "Adding another herb preserves the placement of existing detached pieces.")
	test.expect_equal(board.board_items.get_child_count(), 1, "The newly added intact herb appears beside the detached pieces.")
	test.expect(panel.separate_herb(), "The newly added herb can be detached without clearing the first herb.")
	test.expect_equal(board.get_piece_views().size(), 30, "Both herbs coexist as draggable detached pieces after the second separation.")
	test.expect_equal(runtime.available_count(HERB_ID), herdsman_available_before_mixed_batch - 1, "The multi-herb batch reserves the newly added source plant.")
	test.expect_equal(runtime.available_count(STARDUST_HERB_ID), stardust_available_before_mixed_batch - 1, "The multi-herb batch keeps the first source plant reserved.")
	panel.redo_current_process()
	test.expect_equal(runtime.available_count(HERB_ID), herdsman_available_before_mixed_batch, "Redo releases the second herb reservation from a mixed batch.")
	test.expect_equal(runtime.available_count(STARDUST_HERB_ID), stardust_available_before_mixed_batch, "Redo releases the first herb reservation from a mixed batch.")
	panel.refresh_inventory()
	var current_dew_flask_card := panel.herb_grid.get_children().filter(
		func(child: Node) -> bool:
			return child is HerbCard and (child as HerbCard).ingredient_data.id == DEW_FLASK_HERB_ID
	)[0] as HerbCard
	var dew_flask_drag: Dictionary = current_dew_flask_card._get_drag_data(Vector2.ZERO)
	board._drop_data(board.size * 0.5, dew_flask_drag)
	test.expect(panel.current_herb == dew_flask_herb and panel.pieces.size() == 5, "Dew-Flask Herb enters the real production board with all supplied pieces.")
	test.expect_equal((board.board_items.get_child(0) as HerbAssemblyView).get_child_count(), 5, "The production board visibly reconstructs Dew-Flask Herb.")
	test.expect(panel.separate_herb() and board.get_piece_views().size() == 5, "All Dew-Flask pieces detach into persistent draggable views.")
	var dew_view := board.get_piece_views()[0]
	var dew_view_start := dew_view.global_position
	dew_view._begin_drag_at(dew_view_start + Vector2(6.0, 6.0))
	dew_view._update_drag_to(dew_view_start + Vector2(20.0, 14.0))
	dew_view._end_drag()
	test.expect(not dew_view.global_position.is_equal_approx(dew_view_start), "A detached Dew-Flask piece remains freely draggable on the workbench.")
	var grail_drag: Dictionary = grail_card._get_drag_data(Vector2.ZERO)
	board._drop_data(board.size * 0.5, grail_drag)
	test.expect_equal(panel.source_herbs.size(), 2, "Another herb can be added while detached Dew-Flask pieces remain on the workbench.")
	test.expect_equal(board.get_piece_views().size(), 5, "Detached Dew-Flask pieces remain present while the next herb is intact.")
	test.expect(panel.separate_herb(), "The newly added herb can still be detached after Dew-Flask Herb.")
	test.expect_equal(board.get_piece_views().size(), 10, "Both five-piece herbs coexist as independently draggable pieces after separation.")
	panel.redo_current_process()
	panel.refresh_inventory()
	var current_praise_star_card := panel.herb_grid.get_children().filter(
		func(child: Node) -> bool:
			return child is HerbCard and (child as HerbCard).ingredient_data.id == PRAISE_STAR_MAPLE_ID
	)[0] as HerbCard
	var praise_star_drag: Dictionary = current_praise_star_card._get_drag_data(Vector2.ZERO)
	board._drop_data(board.size * 0.5, praise_star_drag)
	test.expect(panel.current_herb == praise_star_maple and panel.pieces.size() == 9, "Praise-Star Maple enters production as its nine fruits only.")
	test.expect_equal((board.board_items.get_child(0) as HerbAssemblyView).get_child_count(), 9, "The production board never places the full tree into the processing assembly.")
	test.expect(panel.separate_herb() and board.get_piece_views().size() == 9, "All nine tied fruits detach into independently draggable views.")
	panel.redo_current_process()

	# The HerbInventoryArt texture contains exactly twelve painted slots. Extra
	# definitions move to a new page instead of creating a fourth visual row.
	var expected_pages := ceili(float(runtime.ingredients.size()) / float(ProductionPanel.HERB_PAGE_SIZE))
	test.expect_equal(panel.herb_page_count(), expected_pages, "Registered ingredients are split across multiple herb-inventory pages.")
	test.expect_equal(panel.herb_page, 0, "The herb shelf begins on its first page.")
	test.expect_equal(panel.herb_page_label.text, "1 / %d" % expected_pages, "The artwork page indicator reports the first page.")
	test.expect(panel.herb_previous_button.visible and panel.herb_next_button.visible, "Page arrows are available when more than twelve herbs are registered.")
	panel.show_next_herb_page()
	test.expect_equal(panel.herb_page, 1, "The next arrow opens the second herb page.")
	test.expect_equal(panel.herb_page_label.text, "2 / %d" % expected_pages, "The artwork page indicator updates after paging.")
	test.expect_equal(panel.herb_grid.get_child_count(), ProductionPanel.HERB_PAGE_SIZE, "The second page preserves the fixed twelve-slot grid with blank slots.")
	var second_page_cards: Array[Node] = panel.herb_grid.get_children().filter(func(child: Node) -> bool: return child is HerbCard)
	var expected_second_page_cards := mini(ProductionPanel.HERB_PAGE_SIZE, runtime.ingredients.size() - ProductionPanel.HERB_PAGE_SIZE)
	test.expect_equal(second_page_cards.size(), expected_second_page_cards, "The expected count of registered herbs occupy the second page.")
	panel._set_herb_page(expected_pages - 1)
	panel.show_next_herb_page()
	test.expect_equal(panel.herb_page, 0, "The next arrow wraps from the final page to the first page.")
	panel.show_previous_herb_page()
	test.expect_equal(panel.herb_page, expected_pages - 1, "The previous arrow wraps from the first page to the final page.")
	panel.show_next_herb_page()
	test.expect_equal(panel.herb_page, 0, "The next arrow returns to the first page.")
	runtime.free()


static func _center_view_at(board: ProcessBoard, view: ProductionPieceView, target_center: Vector2) -> void:
	view.global_position += target_center - board.get_global_content_rect(view).get_center()
	view.piece.workspace_position = view.position
	view.piece.has_workspace_position = true


static func _place_content_rect(view: ProductionPieceView, target: Rect2) -> void:
	var local_rect := view.get_local_content_rect()
	view.global_position = target.position - local_rect.position


static func _find_alpha_points(view: ProductionPieceView) -> Dictionary:
	var result := {}
	var bitmap_size := view._texture_size
	var draw_rect := view._texture_draw_rect()
	if not view._alpha_bitmap.get_bit(0, 0):
		result["transparent"] = draw_rect.position + Vector2(0.5, 0.5) / Vector2(bitmap_size) * draw_rect.size
	var search_rect := Rect2i(Vector2i.ZERO, bitmap_size)
	var source_rect := view.piece.data.source_rect
	if source_rect.position.x >= 0 and source_rect.position.y >= 0 and source_rect.end.x <= bitmap_size.x and source_rect.end.y <= bitmap_size.y:
		search_rect = source_rect
	for y in range(search_rect.position.y, search_rect.end.y):
		for x in range(search_rect.position.x, search_rect.end.x):
			var opaque := view._alpha_bitmap.get_bit(x, y)
			var key := "opaque" if opaque else "transparent"
			if not result.has(key):
				var uv := (Vector2(x, y) + Vector2(0.5, 0.5)) / Vector2(bitmap_size)
				result[key] = draw_rect.position + uv * draw_rect.size
			if result.size() == 2:
				return result
	return result


static func _find_shared_transparent_point(first: ProductionPieceView, second: ProductionPieceView) -> Vector2:
	var overlap := first.get_global_content_rect().intersection(second.get_global_content_rect())
	if overlap.size.x <= 0.0 or overlap.size.y <= 0.0:
		return Vector2(INF, INF)
	for y in range(17):
		for x in range(17):
			var point := overlap.position + Vector2(
				(float(x) + 0.5) / 17.0 * overlap.size.x,
				(float(y) + 0.5) / 17.0 * overlap.size.y
			)
			if not first.contains_global_point(point) and not second.contains_global_point(point):
				return point
	return Vector2(INF, INF)
