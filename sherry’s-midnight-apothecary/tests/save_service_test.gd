extends RefCounted


static func run(test: TestSupport) -> void:
	var service := SaveService.new("user://architecture_test_save.json")
	service.delete_save()
	var player := PlayerData.new()
	player.money = 88
	player.inventory = {&"moon_mint": 5}

	test.expect_equal(service.save_game(7, GameFlow.Mode.NIGHT, player), OK, "SaveService writes a save.")
	var loaded := service.load_game()
	test.expect_equal(int(loaded.get("day", 0)), 7, "SaveService restores the day.")
	test.expect_equal(int(loaded.get("mode", -1)), GameFlow.Mode.NIGHT, "SaveService restores the mode.")
	var restored := PlayerData.from_save_data(loaded.get("player", {}))
	test.expect_equal(restored.money, 88, "SaveService restores shared player data.")
	test.expect_equal(restored.inventory[&"moon_mint"], 5, "SaveService restores inventory.")
	test.expect_equal(service.delete_save(), OK, "The test save is removed.")

