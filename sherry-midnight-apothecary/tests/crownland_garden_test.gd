extends RefCounted

const DialoguePortraitDatabase := preload("res://night/dialogue/portrait_database.gd")


static func run(test: TestSupport) -> void:
	var dialogue := load("res://day/levels/crownland/garden.dialogue")
	test.expect(dialogue != null, "Crownland garden dialogue resource loads.")

	var packed := load("res://day/levels/crownland/garden.tscn") as PackedScene
	test.expect(packed != null, "Crownland garden scene loads.")
	if packed == null:
		return

	var level := packed.instantiate() as CrownlandGardenLevel
	test.expect(level != null, "Crownland garden scene instantiates as CrownlandGardenLevel.")
	if level == null:
		return

	test.expect(level.get_node_or_null("Backdrop/FS/NormalSky") != null, "Backdrop NormalSky exists.")
	test.expect(level.get_node_or_null("Backdrop/FS/CorruptedSky") != null, "Backdrop CorruptedSky exists.")
	test.expect(level.get_node_or_null("Backdrop/CS/NormalGarden") != null, "Backdrop NormalGarden exists.")
	test.expect(level.get_node_or_null("Backdrop/CS/CorruptedGarden") != null, "Backdrop CorruptedGarden exists.")
	test.expect(level.get_node_or_null("Backdrop/Pillars") != null, "Pillars container exists.")
	test.expect(level.get_node_or_null("Overlay/TaskPanel") != null, "TaskPanel exists.")
	test.expect(level.get_node_or_null("Overlay/FlashOverlay") != null, "FlashOverlay exists.")
	test.expect(level.get_node_or_null("Overlay/PulseVeil") != null, "PulseVeil exists.")

	# Verify portrait resolution for King
	var king_portrait := DialoguePortraitDatabase.get_portrait_texture("国王", "default")
	test.expect(king_portrait != null, "King portrait resolves to Texture2D.")

	# Verify corruption visual state
	level.call("_setup_initial_visuals")
	test.expect((level.get_node("Backdrop/FS/NormalSky") as CanvasItem).visible, "NormalSky is initially visible.")
	test.expect(not (level.get_node("Backdrop/FS/CorruptedSky") as CanvasItem).visible, "CorruptedSky is initially hidden.")
	test.expect((level.get_node("Backdrop/CS/NormalGarden") as CanvasItem).visible, "NormalGarden is initially visible.")
	test.expect(not (level.get_node("Backdrop/CS/CorruptedGarden") as CanvasItem).visible, "CorruptedGarden is initially hidden.")

	# Verify illusion shatter event handler
	level.call("_play_illusion_break")
	test.expect(not (level.get_node("Backdrop/FS/NormalSky") as CanvasItem).visible, "NormalSky is hidden after illusion break.")
	test.expect((level.get_node("Backdrop/FS/CorruptedSky") as CanvasItem).visible, "CorruptedSky is visible after illusion break.")
	test.expect(not (level.get_node("Backdrop/CS/NormalGarden") as CanvasItem).visible, "NormalGarden is hidden after illusion break.")
	test.expect((level.get_node("Backdrop/CS/CorruptedGarden") as CanvasItem).visible, "CorruptedGarden is visible after illusion break.")

	level.free()
