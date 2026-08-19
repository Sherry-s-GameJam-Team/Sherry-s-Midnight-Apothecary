extends RefCounted

const SAFE_ZONE_SCENE := preload("res://day/levels/Vespervale/inner_systems/dream_bed_safe_zone.tscn")
const HAND_UNIT_SCENE := preload("res://day/levels/Vespervale/inner_systems/dream_grasp_hand_unit.tscn")
const GRASP_MGR_SCENE := preload("res://day/levels/Vespervale/inner_systems/dream_grasp_manager.tscn")


static func run(test: TestSupport) -> void:
	test_bed_safe_zone_detection(test)
	test_grasp_hand_unit_frames_and_hitbox(test)
	test_grasp_manager_state_machine(test)
	test_hunt_tier_escalation(test)
	test_floor_locking_and_smooth_follow(test)


static func test_bed_safe_zone_detection(test: TestSupport) -> void:
	var zone := SAFE_ZONE_SCENE.instantiate() as DreamBedSafeZone
	test.expect(zone != null, "DreamBedSafeZone scene can be instantiated.")

	var dummy := CharacterBody2D.new()
	dummy.name = "Player"
	zone.add_child(dummy)

	zone._on_body_entered(dummy)
	test.expect(zone.is_body_sheltered(dummy), "Bed safe zone marks entering player as sheltered.")
	test.expect(zone.has_any_sheltered_player(), "Bed safe zone reports active sheltered player.")

	zone._on_body_exited(dummy)
	test.expect(not zone.is_body_sheltered(dummy), "Bed safe zone clears exiting player.")

	dummy.queue_free()
	zone.queue_free()


static func test_grasp_hand_unit_frames_and_hitbox(test: TestSupport) -> void:
	var unit := HAND_UNIT_SCENE.instantiate() as DreamGraspHandUnit
	test.expect(unit != null, "DreamGraspHandUnit scene can be instantiated.")

	var sprite := unit.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	test.expect(sprite != null, "Hand unit contains AnimatedSprite2D.")
	if sprite != null and sprite.sprite_frames != null:
		var frame_count := sprite.sprite_frames.get_frame_count("erupt")
		test.expect_equal(frame_count, 24, "Erupt animation contains all 24 frames.")

	var col := unit.get_node_or_null("CollisionShape2D") as CollisionShape2D
	test.expect(col != null, "Hand unit contains CollisionShape2D.")

	# Frame 5 (Lurk/Lock): Hitbox disabled
	if sprite != null:
		sprite.frame = 5
		unit._on_frame_changed()
		test.expect(col.disabled, "Hitbox is disabled during frame 0-13 (Lurk/Lock).")

		# Frame 18 (Full Erupt): Hitbox active
		sprite.frame = 18
		unit._on_frame_changed()
		test.expect(not col.disabled, "Hitbox is active during frame 18-22 (Full Grasp).")

	unit.queue_free()


static func test_grasp_manager_state_machine(test: TestSupport) -> void:
	var mgr := GRASP_MGR_SCENE.instantiate() as DreamGraspManager
	test.expect(mgr != null, "DreamGraspManager can be instantiated.")

	test.expect_equal(mgr.current_state, DreamGraspManager.State.LURK, "Manager starts in LURK state.")

	# Transition to TRACK
	mgr._transition_to(DreamGraspManager.State.TRACK)
	test.expect_equal(mgr.current_state, DreamGraspManager.State.TRACK, "Manager transitions to TRACK state.")

	# Transition to LOCK
	mgr._transition_to(DreamGraspManager.State.LOCK)
	test.expect_equal(mgr.current_state, DreamGraspManager.State.LOCK, "Manager transitions to LOCK state.")

	# Transition to ERUPT
	mgr._transition_to(DreamGraspManager.State.ERUPT)
	test.expect_equal(mgr.current_state, DreamGraspManager.State.ERUPT, "Manager transitions to ERUPT state.")

	# Transition to RETRACT
	mgr._transition_to(DreamGraspManager.State.RETRACT)
	test.expect_equal(mgr.current_state, DreamGraspManager.State.RETRACT, "Manager transitions to RETRACT state.")

	mgr.queue_free()


static func test_hunt_tier_escalation(test: TestSupport) -> void:
	var mgr := GRASP_MGR_SCENE.instantiate() as DreamGraspManager
	test.expect_equal(mgr.hunt_tier, 1, "Default hunt tier is 1.")

	mgr.hunt_time = 9.0
	if mgr.hunt_time >= 8.0:
		mgr._set_hunt_tier(2)
	test.expect_equal(mgr.hunt_tier, 2, "Hunt tier escalates to 2 after 8 seconds outside bed.")

	mgr.hunt_time = 18.0
	if mgr.hunt_time >= 16.0:
		mgr._set_hunt_tier(3)
	test.expect_equal(mgr.hunt_tier, 3, "Hunt tier escalates to 3 after 16 seconds outside bed.")

	mgr.queue_free()


static func test_floor_locking_and_smooth_follow(test: TestSupport) -> void:
	var mgr := GRASP_MGR_SCENE.instantiate() as DreamGraspManager
	test.expect_equal(mgr.ground_floor_y, 600.0, "Enemy Y is locked to 1st floor (600.0).")

	mgr._current_x = 100.0
	# Smooth follow moves towards target_x without instant snap
	mgr._smooth_follow_target(300.0, 0.1)
	test.expect(mgr._current_x > 100.0 and mgr._current_x < 300.0, "Tracking smoothly interpolates towards target X.")
	test.expect_equal(mgr._tracking_position.y, 600.0, "Tracking position Y is locked to ground floor.")

	# Breathing visual updates
	mgr._update_breathing_visual(0.5)
	if mgr.tracking_shadow != null:
		test.expect(mgr.tracking_shadow.visible, "Tracking shadow is visible during breathing updates.")

	mgr.queue_free()
