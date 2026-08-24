extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("DAY HEALTH TEST FAILED: %s" % message)


func _run() -> void:
	var player := PlayerData.new()
	var depleted_events: Array[bool] = []
	player.health_depleted.connect(func() -> void: depleted_events.append(true))
	_expect(player.apply_damage(25) == 25 and player.health == 75, "Damage reduces global health.")
	_expect(player.restore_health(10) == 10 and player.health == 85, "Healing restores global health.")
	_expect(player.apply_damage(999) == 85 and player.health == 0, "Damage cannot lower health below zero.")
	_expect(depleted_events.size() == 1, "Zero health emits exactly one depleted signal.")
	player.restore_full_health()
	var checkpoint := player.to_save_data()
	player.money = 88
	player.inventory[&"temporary"] = 3
	player.apply_damage(40)
	player.restore_from_save_data(checkpoint)
	_expect(player.health == player.max_health, "Snapshot restores saved health.")
	_expect(player.money == 0 and not player.inventory.has(&"temporary"), "Snapshot restores full player state.")

	# PlayerHealthHUD UI tests
	var hud_scene: PackedScene = load("res://day/ui/player_health_hud.tscn")
	_expect(hud_scene != null, "PlayerHealthHUD scene loads successfully.")
	var hud: PlayerHealthHUD = hud_scene.instantiate() as PlayerHealthHUD
	_expect(hud != null, "PlayerHealthHUD instantiates properly.")
	root.add_child(hud)
	_expect(hud.anchor_left == 1.0 and hud.anchor_right == 1.0, "PlayerHealthHUD is anchored to top-right.")
	_expect(hud.has_node("Frame") and hud.has_node("BarSlot/SlotBackground"), "PlayerHealthHUD has Frame and slot background.")
	_expect(hud.has_node("BarSlot/HealthBar") and hud.has_node("BarSlot/DelayedHealthBar"), "PlayerHealthHUD has both red health bar and yellow delayed bar.")

	hud.bind_player_data(player)
	_expect(hud.health_bar.value == player.max_health, "HealthBar matches max health on bind.")
	_expect(hud.delayed_health_bar.value == player.max_health, "DelayedHealthBar matches max health on bind.")
	_expect(hud.health_label.text == "HP %d / %d" % [player.health, player.max_health], "HealthLabel displays correct initial HP.")

	# Apply damage: red bar drops immediately, yellow bar initiates delayed catch-up
	player.apply_damage(30)
	_expect(hud.health_bar.value == 70, "Red health bar updates immediately on damage.")
	_expect(hud.health_label.text == "HP 70 / 100", "Health label reflects current damaged HP.")

	# Apply healing: both bars immediately update
	player.restore_health(15)
	_expect(hud.health_bar.value == 85, "Red health bar updates on heal.")
	_expect(hud.delayed_health_bar.value == 85, "Delayed health bar matches healed value immediately.")
	_expect(hud.health_label.text == "HP 85 / 100", "Health label reflects healed HP.")

	hud.queue_free()

	if failures == 0:
		print("Day health and PlayerHealthHUD tests passed.")
		quit(0)
	else:
		quit(1)
