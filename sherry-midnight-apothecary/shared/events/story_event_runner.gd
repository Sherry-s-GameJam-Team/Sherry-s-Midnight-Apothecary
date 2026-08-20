class_name StoryEventRunner
extends Node

const BALLOON_SCENE := preload("res://night/dialogue/apothecary_balloon.tscn")

signal event_completed(event_id: StringName)

var _catalog: StoryEventCatalog
var _player_data: PlayerData
var _current_day := 0
var _is_night := false
var _queue: Array[Dictionary] = []
var _running := false


func configure(catalog: StoryEventCatalog, player_data: PlayerData, current_day: int, is_night: bool) -> void:
	_catalog = catalog
	_player_data = player_data
	_current_day = current_day
	_is_night = is_night


func dispatch(trigger_type: StoryEventTriggerSpec.Type, level_id: StringName = &"", interaction_key: StringName = &"") -> bool:
	var matches := eligible_events(trigger_type, level_id, interaction_key)
	if matches.is_empty():
		return false
	for event: StoryEventDefinition in matches:
		_queue.append({"event": event, "level_id": level_id, "interaction_key": interaction_key})
	if not _running:
		call_deferred("_process_queue")
	return true


func eligible_events(trigger_type: StoryEventTriggerSpec.Type, level_id: StringName = &"", interaction_key: StringName = &"") -> Array[StoryEventDefinition]:
	var result: Array[Dictionary] = []
	if _catalog == null or _player_data == null:
		return []
	for index in range(_catalog.events.size()):
		var event: StoryEventDefinition = _catalog.events[index]
		if event == null or event.trigger == null:
			continue
		if event.trigger.matches(trigger_type, _is_night, level_id, interaction_key) and event.conditions_are_met(_player_data, _current_day):
			result.append({"event": event, "index": index})
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_event: StoryEventDefinition = left.get("event") as StoryEventDefinition
		var right_event: StoryEventDefinition = right.get("event") as StoryEventDefinition
		var left_index: int = int(left.get("index", 0))
		var right_index: int = int(right.get("index", 0))
		return left_index < right_index if left_event.priority == right_event.priority else left_event.priority > right_event.priority
	)
	var ordered: Array[StoryEventDefinition] = []
	for item: Dictionary in result:
		ordered.append(item.get("event") as StoryEventDefinition)
	return ordered


func _process_queue() -> void:
	if _running:
		return
	_running = true
	while not _queue.is_empty() and is_inside_tree():
		var request: Dictionary = _queue.pop_front()
		var event: StoryEventDefinition = request.get("event") as StoryEventDefinition
		if event == null or not event.conditions_are_met(_player_data, _current_day):
			continue
		var completed: bool = await _present_and_apply(event)
		if completed:
			_player_data.set_event_flag(event.completion_flag())
			event_completed.emit(event.id)
	_running = false


func is_completed(event_id: StringName) -> bool:
	return _player_data != null and event_id != &"" and _player_data.has_event_flag(StringName("story_event_completed:%s" % event_id))


func _present_and_apply(event: StoryEventDefinition) -> bool:
	if event.dialogue_resource != null:
		var dialogue_manager: Node = get_node_or_null("/root/DialogueManager")
		if dialogue_manager == null or not dialogue_manager.has_method("show_dialogue_balloon_scene"):
			push_error("StoryEventRunner requires the DialogueManager autoload.")
			return false
		var balloon: Node = dialogue_manager.show_dialogue_balloon_scene(BALLOON_SCENE, event.dialogue_resource, event.dialogue_title)
		if balloon == null:
			return false
		await balloon.tree_exited
		if not is_inside_tree():
			return false
	for action: StoryEventAction in event.actions:
		if action == null or not action.apply_to(_player_data, _current_day):
			push_error("Story event '%s' contains an invalid action." % event.id)
			return false
	return true
