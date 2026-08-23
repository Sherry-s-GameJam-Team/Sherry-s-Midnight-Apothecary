extends RefCounted


static func run(test: TestSupport) -> void:
	var packed := load("res://day/levels/crownland/boss.tscn") as PackedScene
	test.expect(packed != null, "Crownland Boss level scene can be loaded.")
	if packed == null:
		return

	var level := packed.instantiate() as Node2D
	test.expect(level != null, "Crownland Boss level scene instantiates.")
	if level == null:
		return

	test.expect(level.get_node_or_null("Player/SherryCollision") != null, "Boss level deploys Sherry collision.")
	test.expect(level.get_node_or_null("Player/SherryPresentation") != null, "Boss level deploys Sherry presentation.")
	test.expect(level.get_node_or_null("Player/PotionThrower") != null, "Boss level deploys the potion system.")
	test.expect(level.get_node_or_null("Player/Camera2D") is Camera2D, "Boss level deploys a player camera.")
	test.expect(level.get_node_or_null("WorldBounds/Ground") is StaticBody2D, "Boss level deploys a permanent floor collision body.")
	test.expect(level.get_node_or_null("WorldBounds/LeftBarrier") is StaticBody2D, "Boss level deploys the left camera/collision barrier.")
	test.expect(level.get_node_or_null("WorldBounds/RightBarrier") is StaticBody2D, "Boss level deploys the right camera/collision barrier.")
	test.expect(level.get_node_or_null("BossTrigger") is Area2D, "Boss level deploys the battle trigger area.")
	test.expect(level.get_node_or_null("Backdrop") is CanvasLayer, "Boss level background is camera-anchored.")
	test.expect(level.get_node_or_null("Backdrop/RoyalChamber") is TextureRect, "Boss level background covers the camera viewport.")
	test.expect(level.get_node_or_null("CrownlandBossArena") is CrownlandBossArena, "Boss level instances the Crownland Boss Arena.")
	test.expect(level.get_node_or_null("CrownlandBossArena/BossHealthBar/RootContainer/HeaderBox/BossTitle") is Label, "Boss level deploys the Alkeon-style boss health-bar header.")
	test.expect(level.get_node_or_null("CrownlandBossArena/BossHealthBar/RootContainer/BarContainer/HpBar") is ProgressBar, "Boss level deploys the Alkeon-style boss health bar.")
	test.expect(level.get_node_or_null("CrownlandBossArena/BossHealthBar/RootContainer/BarContainer/PillarLabel") is Label, "Boss level retains the pillar counter in the shared health frame.")
	test.expect(level.get_node_or_null("CrownlandBossArena/Pillars/PillarLeft/Hurtbox/CollisionShape2D") is CollisionShape2D, "Boss level serializes the left pillar potion hitbox.")
	test.expect(level.get_node_or_null("UI/StatusPanel/Status") is Label, "Boss level deploys its status UI.")
	test.expect(level.get_node_or_null("DebugUI/DeveloperConsole") is DeveloperConsole, "Boss level deploys the Developer Console.")
	test.expect(level.get_node_or_null("PauseMenuLayer/PauseMenu") != null, "Boss level deploys the standard pause and backpack UI.")
	level.free()

	var end_packed := load("res://day/levels/crownland/end.tscn") as PackedScene
	test.expect(end_packed != null, "Crownland ending scene can be loaded.")
	if end_packed == null:
		return
	var ending := end_packed.instantiate() as Node2D
	test.expect(ending.get_node_or_null("Backdrop") is CanvasLayer, "Ending background is camera-anchored.")
	test.expect(ending.get_node_or_null("Backdrop/SavedKingdom") is TextureRect, "Ending background covers the camera viewport.")
	test.expect(ending.get_node_or_null("Player/Camera2D") is Camera2D, "Ending scene deploys a player camera.")
	test.expect(ending.get_node_or_null("WorldBounds/Ground") is StaticBody2D, "Ending scene deploys ground collision.")
	test.expect(ending.get_node_or_null("DialogueAnchor") is Marker2D, "Ending scene exposes a dialogue anchor.")
	ending.free()
