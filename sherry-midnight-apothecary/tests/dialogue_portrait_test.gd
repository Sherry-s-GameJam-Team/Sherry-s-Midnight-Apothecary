extends RefCounted

const BALLOON_PATH := "res://night/dialogue/apothecary_balloon.tscn"


static func run(test: TestSupport) -> void:
	# Test 1: DialoguePortraitDatabase mapping & resolution
	var villager_tex := DialoguePortraitDatabase.get_portrait_texture("年轻村民", "default")
	test.expect(villager_tex != null, "Database resolves texture for Chinese NPC identity '年轻村民'.")

	var villager_id_tex := DialoguePortraitDatabase.get_portrait_texture("01_young_villager", "default")
	test.expect(villager_id_tex != null, "Database resolves texture for NPC folder ID '01_young_villager'.")

	var scholar_tex := DialoguePortraitDatabase.get_portrait_texture("女学者", "default")
	test.expect(scholar_tex != null, "Database resolves texture for '女学者'.")

	var mew_tex := DialoguePortraitDatabase.get_portrait_texture("喵呜", "default")
	test.expect(mew_tex != null, "Database resolves texture for '喵呜'.")

	# Test slot normalization
	test.expect_equal(DialoguePortraitDatabase.normalize_slot("left"), "left", "Normalize 'left'")
	test.expect_equal(DialoguePortraitDatabase.normalize_slot("左"), "left", "Normalize '左'")
	test.expect_equal(DialoguePortraitDatabase.normalize_slot("r"), "right", "Normalize 'r'")
	test.expect_equal(DialoguePortraitDatabase.normalize_slot("右侧"), "right", "Normalize '右侧'")
	test.expect_equal(DialoguePortraitDatabase.normalize_slot("mid"), "center", "Normalize 'mid'")

	# Test 2: DialoguePortraitSlot functionality
	var slot := DialoguePortraitSlot.new()
	slot.slot_id = DialoguePortraitSlot.SlotId.LEFT
	slot._ready()

	slot.show_portrait("年轻村民", "default", "slide_in")
	test.expect(slot.is_active, "Slot is active after show_portrait.")
	test.expect_equal(slot.current_character, "年轻村民", "Slot tracks current character.")
	test.expect_equal(slot.current_expression, "default", "Slot tracks current expression.")

	# Focus dimming
	slot.set_focused(false, false)
	test.expect_equal(slot.modulate.r, slot.unfocused_modulate.r, "Unfocused slot dims modulate.")
	slot.set_focused(true, false)
	test.expect_equal(slot.modulate.r, slot.focused_modulate.r, "Focused slot restores modulate.")

	slot.clear_instant()
	test.expect(not slot.is_active, "Slot clears instantly.")
	slot.free()

	# Test 3: ApothecaryBalloon portrait integration
	var balloon_scene := load(BALLOON_PATH) as PackedScene
	test.expect(balloon_scene != null, "Apothecary balloon scene loads.")
	if balloon_scene == null:
		return

	var balloon := balloon_scene.instantiate() as ApothecaryDialogueBalloon
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		tree.root.add_child(balloon)

	balloon._has_entered = true
	balloon._is_transitioning = false

	test.expect(balloon.get_slot("left") != null, "Balloon contains LeftSlot.")
	test.expect(balloon.get_slot("center") != null, "Balloon contains CenterSlot.")
	test.expect(balloon.get_slot("right") != null, "Balloon contains RightSlot.")

	# Test direct portrait commands
	balloon.show_portrait("年轻村民", "default", "left", "slide_in")
	test.expect(balloon.get_slot("left").is_active, "Left slot activated via show_portrait command.")
	test.expect_equal(balloon.get_slot("left").current_character, "年轻村民", "Left slot displays '年轻村民'.")

	balloon.show_portrait("女学者", "default", "right", "slide_in")
	test.expect(balloon.get_slot("right").is_active, "Right slot activated via show_portrait command.")

	# Test focus update: speaking as '年轻村民'
	balloon.set_portrait_focus("年轻村民")
	test.expect(balloon.get_slot("left").is_active, "Left slot remains active.")

	# Test hide and clear
	balloon.hide_portrait("left", "fade_out")
	test.expect(not balloon.get_slot("left").is_active, "Left slot marked inactive after hide_portrait.")

	balloon.clear_portraits()
	test.expect(not balloon.get_slot("left").is_active and not balloon.get_slot("right").is_active, "All slots cleared after clear_portraits.")

	# Test 4: Syntax tag parsing via dummy DialogueLine
	var dummy_line := DialogueLine.new()
	dummy_line.character = "铁匠"
	dummy_line.text = "打造药剂坩埚需要上好的精金铁矿。"
	dummy_line.tags = PackedStringArray(["portrait(slot=center, expr=happy, anim=bounce)"])

	balloon._process_portrait_syntax(dummy_line)
	test.expect(balloon.center_slot.is_active, "Tag syntax '#portrait(slot=center...)' activates CenterSlot.")
	test.expect_equal(balloon.center_slot.current_character, "铁匠", "CenterSlot set to speaker '铁匠'.")
	test.expect_equal(balloon.center_slot.current_expression, "happy", "CenterSlot set to expression 'happy'.")

	# Test BBCode inline syntax
	balloon.clear_portraits()
	dummy_line.character = "修女"
	dummy_line.text = "[portrait=修女:default:left]愿月光庇佑你的药剂实验。"
	dummy_line.tags = PackedStringArray()

	balloon._process_portrait_syntax(dummy_line)
	test.expect(balloon.get_slot("left").is_active, "Inline BBCode '[portrait=...]' activates LeftSlot.")
	test.expect_equal(balloon.get_slot("left").current_character, "修女", "LeftSlot displays '修女'.")

	# Test 5: Embedded #tag in character name (e.g. "炉边烤鱼的少女 #left(happy, bounce)")
	balloon.clear_portraits()
	dummy_line.character = "炉边烤鱼的少女 #left(happy, bounce)"
	dummy_line.text = "欸，人类，要来点咱的烤鱼吗？"
	dummy_line.tags = PackedStringArray()

	test.expect_equal(balloon._clean_character_name(dummy_line.character), "炉边烤鱼的少女", "Clean character name strips embedded #tags.")
	balloon._process_portrait_syntax(dummy_line)
	test.expect(balloon.get_slot("left").is_active, "Embedded #tag in character activates left slot.")
	test.expect_equal(balloon.get_slot("left").current_character, "炉边烤鱼的少女", "LeftSlot displays clean character '炉边烤鱼的少女'.")
	test.expect_equal(balloon.get_slot("left").current_expression, "happy", "LeftSlot gets expression 'happy'.")

	# Test 6: Rollback functionality (回退功能返回上句话，不打开历史窗口)
	balloon.dialogue_line = dummy_line
	balloon._save_history_snapshot()
	test.expect_equal(balloon._history_stack.size(), 1, "Snapshot saved in _history_stack.")

	# Advance to second line
	var line2 := DialogueLine.new()
	line2.character = "雪莉 #right(thinking)"
	line2.text = "请问这里是……？"
	line2.tags = PackedStringArray()
	balloon.dialogue_line = line2
	balloon._process_portrait_syntax(line2)
	test.expect(balloon.get_slot("right").is_active, "Right slot active for line 2.")

	# Press back button
	balloon.history_panel.hide()
	balloon._on_back_pressed()
	test.expect(not balloon.history_panel.visible, "Back button does NOT open history panel.")
	test.expect_equal(balloon.character_label.text, "炉边烤鱼的少女", "Back button restored previous character.")
	test.expect_equal(balloon.dialogue_label.dialogue_line.text, "欸，人类，要来点咱的烤鱼吗？", "Back button restored previous text.")

	# Test 7: History button opens history panel (回溯键打开历史窗口)
	balloon._on_history_pressed()
	test.expect(balloon.history_panel.visible, "History button opens history panel.")
	balloon._on_history_close_pressed()
	test.expect(not balloon.history_panel.visible, "History close button hides history panel.")

	# Test 8: Fast forward mode (快进键与Ctrl)
	balloon.fast_mode = false
	balloon._ctrl_fast_active = false
	test.expect(not balloon._is_fast_forward_active(), "Fast forward inactive initially.")
	balloon._on_fast_pressed()
	test.expect(balloon.fast_mode, "Fast button toggles fast_mode true.")
	test.expect(balloon._is_fast_forward_active(), "_is_fast_forward_active true when fast_mode true.")
	balloon._on_fast_pressed()
	test.expect(not balloon.fast_mode, "Fast button toggles fast_mode off.")
	balloon._ctrl_fast_active = true
	test.expect(balloon._is_fast_forward_active(), "_is_fast_forward_active true when Ctrl is active.")

	balloon.clear_portraits()
	balloon.free()
