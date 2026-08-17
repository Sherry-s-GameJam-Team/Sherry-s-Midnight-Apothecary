extends RefCounted

const LEVER_SCENE := preload("res://day/interactables/control_system/lever_switch.tscn")
const PLATE_SCENE := preload("res://day/interactables/control_system/pressure_plate.tscn")
const PLATE_A_SCENE := preload("res://day/interactables/control_system/pressure_plate_a.tscn")
const PLATE_SQUARE_SCENE := preload("res://day/interactables/control_system/pressure_plate_square.tscn")


static func run(test: TestSupport) -> void:
	var tree := Engine.get_main_loop() as SceneTree

	# Test Lever Switch
	var lever := LEVER_SCENE.instantiate() as LeverSwitchController
	test.expect(lever != null, "LeverSwitch instantiates correctly.")
	if lever != null:
		tree.root.add_child(lever)
		test.expect(lever.texture_off != null, "LeverSwitch has texture_off assigned.")
		test.expect(lever.texture_on != null, "LeverSwitch has texture_on assigned.")
		test.expect(lever._sprite != null, "LeverSwitch has Sprite2D node.")
		test.expect_equal(lever._sprite.texture, lever.texture_off, "LeverSwitch starts with texture_off.")

		lever.set_active(true)
		test.expect(lever.is_active, "LeverSwitch sets active.")
		test.expect_equal(lever._sprite.texture, lever.texture_on, "LeverSwitch switches to texture_on when active.")

		lever.set_active(false)
		test.expect(not lever.is_active, "LeverSwitch deactivates.")
		test.expect_equal(lever._sprite.texture, lever.texture_off, "LeverSwitch switches back to texture_off when inactive.")
		lever.free()

	# Test Pressure Plate
	var plate := PLATE_SCENE.instantiate() as PressurePlateController
	test.expect(plate != null, "PressurePlate instantiates correctly.")
	if plate != null:
		tree.root.add_child(plate)
		test.expect(plate.texture_off != null, "PressurePlate has texture_off assigned.")
		test.expect(plate.texture_on != null, "PressurePlate has texture_on assigned.")
		test.expect(plate._sprite != null, "PressurePlate has Sprite2D node.")
		test.expect_equal(plate._sprite.texture, plate.texture_off, "PressurePlate starts with texture_off.")

		plate.set_active(true)
		test.expect(plate.is_active, "PressurePlate sets active.")
		test.expect_equal(plate._sprite.texture, plate.texture_on, "PressurePlate switches to texture_on when active.")

		plate.set_active(false)
		test.expect_equal(plate._sprite.texture, plate.texture_off, "PressurePlate switches back to texture_off when inactive.")
		plate.free()

	# Test Variants
	var plate_a := PLATE_A_SCENE.instantiate() as PressurePlateController
	test.expect(plate_a != null, "PressurePlateA instantiates correctly.")
	if plate_a != null:
		tree.root.add_child(plate_a)
		test.expect(plate_a.texture_off != null and plate_a.texture_on != null, "PressurePlateA has textures assigned.")
		plate_a.free()

	var plate_sq := PLATE_SQUARE_SCENE.instantiate() as PressurePlateController
	test.expect(plate_sq != null, "PressurePlateSquare instantiates correctly.")
	if plate_sq != null:
		tree.root.add_child(plate_sq)
		test.expect(plate_sq.texture_off != null and plate_sq.texture_on != null, "PressurePlateSquare has textures assigned.")
		plate_sq.free()
