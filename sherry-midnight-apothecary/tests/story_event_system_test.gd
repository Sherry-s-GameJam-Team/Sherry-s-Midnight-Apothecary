extends RefCounted


static func run(test: TestSupport) -> void:
	var player := PlayerData.new()
	player.money = 80
	player.store_reputation = 75
	player.add_story_item(&"moon_note", 2)
	player.add_inventory_item(&"herb", 3)
	player.unlock_level(&"forest")
	player.set_event_flag(&"chapter_one")

	var day_condition := StoryEventCondition.new()
	day_condition.type = StoryEventCondition.Type.DAY_RANGE
	day_condition.minimum_day = 2
	day_condition.maximum_day = 4
	test.expect(day_condition.is_met(player, 3), "Day-range conditions accept an included day.")
	test.expect(not day_condition.is_met(player, 5), "Day-range conditions reject an excluded day.")

	for check in [
		_condition(StoryEventCondition.Type.EVENT_FLAG_SET, &"chapter_one", 1),
		_condition(StoryEventCondition.Type.EVENT_FLAG_CLEAR, &"chapter_two", 1),
		_condition(StoryEventCondition.Type.STORY_ITEM_AT_LEAST, &"moon_note", 2),
		_condition(StoryEventCondition.Type.INVENTORY_AT_LEAST, &"herb", 3),
		_condition(StoryEventCondition.Type.LEVEL_UNLOCKED, &"forest", 1),
		_condition(StoryEventCondition.Type.MONEY_AT_LEAST, &"", 80),
		_condition(StoryEventCondition.Type.REPUTATION_AT_LEAST, &"", 75),
	]:
		test.expect((check as StoryEventCondition).is_met(player, 3), "Configured story-event condition evaluates against PlayerData.")

	var set_flag := _action(StoryEventAction.Type.SET_EVENT_FLAG, &"event_action_flag", 1)
	var reward_item := _action(StoryEventAction.Type.GRANT_STORY_ITEM, &"chapter_reward", 2)
	var reward_inventory := _action(StoryEventAction.Type.GRANT_INVENTORY_ITEM, &"herb", 2)
	test.expect(set_flag.apply_to(player), "Event actions can set persistent event flags.")
	test.expect(reward_item.apply_to(player), "Event actions can grant story items.")
	test.expect(reward_inventory.apply_to(player), "Event actions can grant inventory items.")
	test.expect(player.has_event_flag(&"event_action_flag"), "Event flags are stored separately from tutorial flags.")
	test.expect_equal(player.story_items[&"chapter_reward"], 2, "Story-item action grants its configured amount.")
	test.expect_equal(player.inventory[&"herb"], 5, "Inventory action grants its configured amount.")
	var daily_task := _action(StoryEventAction.Type.SET_DAILY_TASK, &"red_fountain", 1)
	daily_task.task_title = "调查流明街广场的红色喷泉"
	test.expect(daily_task.apply_to(player, 3), "Event actions can set the current daily task.")
	test.expect_equal(player.get_active_daily_task(3).get("id", ""), "red_fountain", "The current day's task is available on its assigned day.")
	test.expect(player.get_active_daily_task(4).is_empty(), "A daily task card is absent on later days.")

	var low_priority := _event(&"low", 1, StoryEventTriggerSpec.Type.LEVEL_ENTERED, &"market")
	var high_priority := _event(&"high", 10, StoryEventTriggerSpec.Type.LEVEL_ENTERED, &"market")
	var same_priority_later := _event(&"later", 10, StoryEventTriggerSpec.Type.LEVEL_ENTERED, &"market")
	var catalog := StoryEventCatalog.new()
	catalog.events = [low_priority, high_priority, same_priority_later]
	var runner := StoryEventRunner.new()
	runner.configure(catalog, player, 3, false)
	var ordered := runner.eligible_events(StoryEventTriggerSpec.Type.LEVEL_ENTERED, &"market")
	test.expect_equal(ordered.map(func(event: StoryEventDefinition) -> StringName: return event.id), [&"high", &"later", &"low"], "Eligible events sort by priority then catalog order.")
	test.expect(runner.dispatch(StoryEventTriggerSpec.Type.LEVEL_ENTERED, &"market"), "Level-entry dispatch accepts matching events.")
	test.expect(not runner.dispatch(StoryEventTriggerSpec.Type.INTERACTION, &"", &"missing"), "Interaction dispatch ignores unmatched keys.")
	player.set_event_flag(high_priority.completion_flag())
	var after_completion := runner.eligible_events(StoryEventTriggerSpec.Type.LEVEL_ENTERED, &"market")
	test.expect_equal(after_completion.map(func(event: StoryEventDefinition) -> StringName: return event.id), [&"later", &"low"], "Completed events are excluded from later dispatches.")

	var day_trigger := StoryEventTriggerSpec.new()
	day_trigger.type = StoryEventTriggerSpec.Type.RUNTIME_ENTERED
	day_trigger.runtime_mode = StoryEventTriggerSpec.RuntimeMode.DAY
	test.expect(day_trigger.matches(StoryEventTriggerSpec.Type.RUNTIME_ENTERED, false, &"", &""), "Day runtime trigger matches the day entry point.")
	var night_trigger := StoryEventTriggerSpec.new()
	night_trigger.type = StoryEventTriggerSpec.Type.RUNTIME_ENTERED
	night_trigger.runtime_mode = StoryEventTriggerSpec.RuntimeMode.NIGHT
	test.expect(night_trigger.matches(StoryEventTriggerSpec.Type.RUNTIME_ENTERED, true, &"", &""), "Night runtime trigger matches the night entry point.")
	var interaction_trigger := StoryEventTriggerSpec.new()
	interaction_trigger.type = StoryEventTriggerSpec.Type.INTERACTION
	interaction_trigger.interaction_key = &"notice_board"
	test.expect(interaction_trigger.matches(StoryEventTriggerSpec.Type.INTERACTION, false, &"", &"notice_board"), "Interaction trigger matches its editor key.")

	var saved := player.to_save_data()
	var restored := PlayerData.from_save_data(saved)
	test.expect(restored.has_event_flag(&"event_action_flag"), "Event flags survive save/load round trips.")
	test.expect_equal(restored.get_active_daily_task(3).get("id", ""), "red_fountain", "The active daily task round-trips with its assigned day.")
	var legacy := PlayerData.from_save_data({"version": 9})
	test.expect(legacy.event_flags.is_empty(), "Old saves load with an empty event-flag store.")

	var luca_intro := load("res://shared/definitions/events/day_one_bedroom_luca_intro.tres") as StoryEventDefinition
	test.expect(luca_intro != null, "The day-one Town blood-fountain event resource loads.")
	if luca_intro != null:
		test.expect_equal(luca_intro.id, &"day_one_blood_fountain", "The event has a stable blood-fountain completion ID.")
		test.expect_equal(luca_intro.trigger.interaction_key, &"issue_day_one_fountain", "The Town performance explicitly triggers the event after its entrance animation.")
		test.expect(luca_intro.priority > 0 and luca_intro.dialogue_resource != null, "The Town opening has priority and a dialogue resource.")

	var bedroom_luca := load("res://shared/definitions/events/day_one_bedroom_luca_urgent.tres") as StoryEventDefinition
	test.expect(bedroom_luca != null, "The day-one bedroom Luca event resource loads.")
	if bedroom_luca != null:
		test.expect_equal(bedroom_luca.id, &"day_one_bedroom_luca_urgent", "The bedroom event has a stable completion ID.")
		test.expect_equal(bedroom_luca.trigger.interaction_key, &"day_one_luca_urgent", "The day-one bedroom presentation dispatches the Luca dialogue event after the walk-in.")
		test.expect(bedroom_luca.conditions_are_met(PlayerData.new(), 1), "The bedroom Luca event is eligible on day one.")
		test.expect(not bedroom_luca.conditions_are_met(PlayerData.new(), 0), "The bedroom Luca event is ineligible before day one.")


static func _condition(type: StoryEventCondition.Type, key: StringName, amount: int) -> StoryEventCondition:
	var result := StoryEventCondition.new()
	result.type = type
	result.key = key
	result.amount = amount
	return result


static func _action(type: StoryEventAction.Type, key: StringName, amount: int) -> StoryEventAction:
	var result := StoryEventAction.new()
	result.type = type
	result.key = key
	result.amount = amount
	return result


static func _event(id: StringName, priority: int, trigger_type: StoryEventTriggerSpec.Type, level_id: StringName) -> StoryEventDefinition:
	var trigger := StoryEventTriggerSpec.new()
	trigger.type = trigger_type
	trigger.level_id = level_id
	var event := StoryEventDefinition.new()
	event.id = id
	event.priority = priority
	event.trigger = trigger
	return event
