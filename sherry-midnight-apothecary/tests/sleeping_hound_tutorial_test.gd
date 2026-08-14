extends RefCounted


static func run(test: TestSupport) -> void:
	var npc_source := FileAccess.get_file_as_string("res://day/levels/grassland/npc/sleeping_hound/sleeping_hound_npc.gd")
	test.expect(npc_source.contains('extra_game_states.append({"player_data": player_data})'), "Sleeping hound dialogue passes PlayerData under the player_data state name.")
	test.expect(npc_source.contains('dialogue_start_title = "repeat" if has_seen_follow_up else "first"'), "Sleeping hound selects a separate follow-up dialogue title after the first conversation.")
	var luca_dialogue_source := FileAccess.get_file_as_string("res://day/levels/grassland/npc/sleeping_hound/luca_after_purification.dialogue")
	test.expect(luca_dialogue_source.contains("~ first") and luca_dialogue_source.contains("~ repeat"), "Luca dialogue defines separate first and repeat branches.")
	var dialogue_source := FileAccess.get_file_as_string("res://day/levels/grassland/npc/sleeping_hound/sleeping_hound.dialogue")
	test.expect(dialogue_source.contains("emit_dialogue_event(\"sleeping_hound_tutorial_begin\""), "Sleeping hound dialogue emits the event that starts the gameplay tutorial.")
	test.expect(dialogue_source.contains("使用净化药水 [if potion_count(\"purification_potion\") >= 1]"), "Using purification is offered only when the dedicated potion is owned.")
	test.expect(dialogue_source.contains("炼制净化药水 [if potion_count(\"purification_potion\") < 1]"), "Missing purification offers the brewing hint instead.")
	var packed := load("res://day/levels/grassland/grass.tscn") as PackedScene
	var grass := packed.instantiate() as GrasslandEnvironment
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(grass)
	var tutorial := grass.get_node("SleepingHoundTutorial") as SleepingHoundTutorial
	var npc := grass.get_node("SleepingHoundNPC") as SleepingHoundNPC
	var player_data := grass.get_player_data()
	var thrower := grass.get_node("Player/PotionThrower") as PotionThrower
	var task_complete_ui := grass.get_node("TaskCompleteUI") as TaskCompleteUI
	tutorial._initialize()

	npc.dialogue_event.emit(&"sleeping_hound_tutorial_begin", "purification_potion")
	test.expect_equal(tutorial.stage, SleepingHoundTutorial.Stage.WAIT_BACKPACK, "Dialogue event starts the sleeping hound tutorial.")
	test.expect(player_data.potion_count(&"purification_potion") >= 1, "Tutorial supplies purification potion when needed.")
	tutorial._pause_menu.visible = true
	tutorial._pause_menu.select_page(PauseMenu.Page.BACKPACK)
	tutorial._inventory_page.select_potion(&"purification_potion")
	tutorial._inventory_page.equip_selected_to_slot(0)
	tutorial._pause_menu.close()
	test.expect_equal(tutorial.stage, SleepingHoundTutorial.Stage.AIM_AND_THROW, "Equipping and returning starts the throw lesson.")
	test.expect(thrower.visible and npc.target_guide.visible, "Throw lesson displays controls and the hound target arrow.")

	var purification := load("res://shared/definitions/data/potions/purification_potion.tres") as PotionData
	var missed := (load("res://shared/potions/runtime/potion_projectile.tscn") as PackedScene).instantiate() as PotionProjectile
	missed.potion = purification
	var reloaded := {"value": false}
	tutorial.purification_potion_reloaded.connect(func() -> void: reloaded.value = true)
	tutorial._on_projectile_spawned(missed)
	player_data.potions.erase(&"purification_potion")
	tutorial._on_projectile_broken(npc.global_position + Vector2(900.0, 0.0), Vector2.UP, missed)
	test.expect_equal(tutorial.stage, SleepingHoundTutorial.Stage.AIM_AND_THROW, "A missed throw requests another attempt.")
	test.expect(reloaded.value and player_data.potion_count(&"purification_potion") >= 1, "An empty purification potion is automatically replenished.")

	var hit := (load("res://shared/potions/runtime/potion_projectile.tscn") as PackedScene).instantiate() as PotionProjectile
	hit.potion = purification
	var success_signalled := {"value": false}
	npc.purification_succeeded.connect(func() -> void: success_signalled.value = true)
	tutorial._on_projectile_spawned(hit)
	tutorial._on_projectile_broken(npc.global_position + tutorial.target_offset, Vector2.UP, hit)
	test.expect_equal(tutorial.stage, SleepingHoundTutorial.Stage.COMPLETE, "A purification potion inside the target completes the tutorial.")
	test.expect(success_signalled.value, "Successful purification emits the NPC success signal.")
	test.expect(not npc.target_guide.visible, "Success hides the hound target arrow.")
	test.expect(npc.is_purified(), "Success changes the corrupted hound into purified Luca.")
	test.expect(not npc.visual.visible and npc.luca_visual.visible, "Purified Luca replaces the corrupted sleeping sprite.")
	test.expect_equal(npc.luca_visual.animation, &"idle", "Purified Luca uses the idle animation from Luca's frame resource.")
	test.expect(npc.luca_visual.is_playing(), "Purified Luca's idle animation loops after task completion.")
	test.expect_equal(npc.luca_visual.sprite_frames.get_frame_count(&"idle"), 29, "Purified Luca uses all 29 idle frames.")
	test.expect(npc.luca_visual.sprite_frames.get_animation_loop(&"idle"), "Purified Luca idle animation is configured to loop.")
	test.expect(npc.dialogue_resource == npc.post_purification_dialogue_resource, "Purified Luca switches to the post-task dialogue resource.")
	test.expect(task_complete_ui != null and task_complete_ui.is_showing(), "Successful purification presents the Grassland task-complete UI.")
	test.expect(task_complete_ui.effect.is_playing(), "Task-complete UI starts its visual burst effect.")
	test.expect(task_complete_ui.complete_chime.playing, "Task-complete UI starts its success sound.")
	task_complete_ui.dismiss()
	test.expect(not task_complete_ui.is_showing(), "Task-complete UI can be dismissed to continue exploring.")
	test.expect(npc._interaction_enabled, "Dismissing task-complete UI restores hound interaction.")
	test.expect_equal(npc.interaction_hint_text, "按[E]与卢卡交谈", "Post-task E prompt identifies Luca.")
	test.expect(not tree.has_meta("day_modal_input_locked"), "Dismissing task-complete UI releases the daytime input lock.")

	missed.free()
	hit.free()
	grass.free()

	var restored_grass := packed.instantiate() as GrasslandEnvironment
	var restored_data := restored_grass.get_player_data()
	restored_data.tutorial_flags["sleeping_hound_purification_complete"] = true
	tree.root.add_child(restored_grass)
	var restored_tutorial := restored_grass.get_node("SleepingHoundTutorial") as SleepingHoundTutorial
	var restored_luca := restored_grass.get_node("SleepingHoundNPC") as SleepingHoundNPC
	restored_tutorial._initialize()
	test.expect_equal(restored_tutorial.stage, SleepingHoundTutorial.Stage.COMPLETE, "Reloading Grass restores the completed purification stage.")
	test.expect(restored_luca.is_purified() and restored_luca.luca_visual.visible, "Reloading Grass restores Luca's looping idle presentation.")
	test.expect(restored_luca._interaction_enabled, "Reloaded Luca remains available for E dialogue.")
	restored_grass.free()
