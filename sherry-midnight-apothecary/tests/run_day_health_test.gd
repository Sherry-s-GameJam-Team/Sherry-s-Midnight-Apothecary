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
	if failures == 0:
		print("Day health data test passed.")
		quit(0)
	else:
		quit(1)
