class_name VillageDayTwoIssue
extends Node2D

## Day-two village issue gate.  The local scene owns visibility and crossing
## presentation; StoryEventRunner owns the repeat-safe dialogue completion.

const DELIVERY_COMPLETE_FLAG: StringName = &"mew_order_delivered"
const EVENT_ID: StringName = &"village_day_two_down"
const INTERACTION_KEY: StringName = &"village_day_two_down"
const REQUIRED_DAY := 2 # Narrative day two uses internal day 2.
const DELIVERY_HINT := "请先交付订单给顾客"
const ROPE_ITEM_ID: StringName = &"village_rope_spool"
const ROPE_REQUIRED := 5
const ROPE_PICKUP_RANGE := 180.0
const ROPE_HINT := "按[E]收集纤绳"

@onready var mew: MewNPC = $issue_Mews
@onready var idle_loop: AnimatedSprite2D = get_node_or_null("../CS/saved/IdleLoop") as AnimatedSprite2D
@onready var down_marker: Marker2D = $down
@onready var rope_root: Node2D = get_node_or_null("../CS/rope") as Node2D

var _runtime: DayRuntime
var _player: CharacterBody2D
var _previous_player_x := 0.0
var _hint_ui: TopHintUI
var _rope_sprites: Array[Sprite2D] = []
var _nearby_rope: Sprite2D


func _ready() -> void:
	_runtime = _find_runtime()
	_player = get_tree().get_first_node_in_group("dialogue_lockable") as CharacterBody2D
	if _player == null:
		_player = get_tree().root.find_child("Player", true, false) as CharacterBody2D
	if _runtime == null or _runtime.day != REQUIRED_DAY:
		visible = false
		set_process(false)
		set_process_input(false)
		return

	visible = true
	_set_idle_loop_visible(_has_completed_event())
	_setup_ropes()
	if _player != null:
		_previous_player_x = _player.global_position.x
	set_process(true)
	set_process_input(true)


func _exit_tree() -> void:
	_hide_delivery_hint()


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_update_nearby_rope()
	var current_x := _player.global_position.x
	if _previous_player_x <= down_marker.global_position.x and current_x > down_marker.global_position.x:
		_on_crossed_down_from_left()
	_previous_player_x = current_x


func _on_crossed_down_from_left() -> void:
	if _has_completed_event():
		_set_idle_loop_visible(true)
		_hide_delivery_hint()
		return
	if not _has_delivered_order():
		_hide_rope_hint()
		_show_delivery_hint()
		return
	if _rope_count() < ROPE_REQUIRED:
		_hide_rope_hint()
		_show_rope_requirement_hint()
		return

	_hide_rope_hint()
	_hide_delivery_hint()
	if _runtime != null and _runtime.dispatch_story_event_interaction(INTERACTION_KEY):
		_set_idle_loop_visible(true)


func _has_delivered_order() -> bool:
	var player_data := _runtime.get_player_data() if _runtime != null else null
	return player_data != null and player_data.has_event_flag(DELIVERY_COMPLETE_FLAG)


func _has_completed_event() -> bool:
	var player_data := _runtime.get_player_data() if _runtime != null else null
	return player_data != null and player_data.has_event_flag(StringName("story_event_completed:%s" % EVENT_ID))


func _setup_ropes() -> void:
	if rope_root == null:
		push_warning("VillageDayTwoIssue could not resolve CS/rope; rope collection is unavailable in this scene instance.")
		return
	for child in rope_root.get_children():
		var rope := child as Sprite2D
		if rope == null:
			continue
		_rope_sprites.append(rope)
		rope.visible = not _is_rope_collected(rope)


func _set_idle_loop_visible(visible: bool) -> void:
	if idle_loop != null:
		idle_loop.visible = visible


func _process_rope_interaction(event: InputEvent) -> void:
	if _nearby_rope == null or not is_instance_valid(_nearby_rope) or not _is_interact_event(event):
		return
	get_viewport().set_input_as_handled()
	_collect_rope(_nearby_rope)


func _input(event: InputEvent) -> void:
	_process_rope_interaction(event)


func _update_nearby_rope() -> void:
	var closest: Sprite2D
	var closest_distance := ROPE_PICKUP_RANGE
	for rope in _rope_sprites:
		if not is_instance_valid(rope) or _is_rope_collected(rope):
			continue
		var distance := rope.global_position.distance_to(_player.global_position)
		if distance <= closest_distance:
			closest = rope
			closest_distance = distance
	if closest == _nearby_rope:
		return
	_set_rope_highlight(_nearby_rope, false)
	_nearby_rope = closest
	_set_rope_highlight(_nearby_rope, true)
	if _nearby_rope != null:
		_show_rope_hint()
	else:
		_hide_rope_hint()


func _collect_rope(rope: Sprite2D) -> void:
	if _is_rope_collected(rope):
		return
	var player_data := _runtime.get_player_data() if _runtime != null else null
	if player_data == null:
		return
	player_data.set_event_flag(_rope_flag(rope))
	player_data.add_inventory_item(ROPE_ITEM_ID, 1)
	rope.visible = false
	_nearby_rope = null
	_hide_rope_hint()


func _set_rope_highlight(rope: Sprite2D, highlighted: bool) -> void:
	if rope == null or not is_instance_valid(rope) or _is_rope_collected(rope):
		return
	rope.modulate = Color(1.35, 1.22, 0.62, 1.0) if highlighted else Color.WHITE


func _is_rope_collected(rope: Sprite2D) -> bool:
	var player_data := _runtime.get_player_data() if _runtime != null else null
	return player_data != null and player_data.has_event_flag(_rope_flag(rope))


func _rope_flag(rope: Sprite2D) -> StringName:
	return StringName("village_rope_collected:%s" % rope.name)


func _rope_count() -> int:
	var player_data := _runtime.get_player_data() if _runtime != null else null
	return int(player_data.inventory.get(ROPE_ITEM_ID, 0)) if player_data != null else 0


func _show_delivery_hint() -> void:
	var hint_ui := _resolve_hint_ui()
	if hint_ui != null:
		hint_ui.show_interaction_hint(_hint_id(), DELIVERY_HINT)


func _show_rope_requirement_hint() -> void:
	var hint_ui := _resolve_hint_ui()
	if hint_ui != null:
		hint_ui.show_interaction_hint(_hint_id(), "目前还差%d盘纤绳" % maxi(ROPE_REQUIRED - _rope_count(), 0))


func _show_rope_hint() -> void:
	var hint_ui := _resolve_hint_ui()
	if hint_ui != null:
		hint_ui.show_interaction_hint(_rope_hint_id(), ROPE_HINT)


func _hide_delivery_hint() -> void:
	var hint_ui := _resolve_hint_ui()
	if hint_ui != null:
		hint_ui.hide_interaction_hint(_hint_id())


func _hide_rope_hint() -> void:
	var hint_ui := _resolve_hint_ui()
	if hint_ui != null:
		hint_ui.hide_interaction_hint(_rope_hint_id())


func _resolve_hint_ui() -> TopHintUI:
	if is_instance_valid(_hint_ui):
		return _hint_ui
	_hint_ui = get_tree().root.find_child("TopHintUI", true, false) as TopHintUI
	return _hint_ui


func _hint_id() -> String:
	return "village_day_two_down_%s" % get_instance_id()


func _rope_hint_id() -> String:
	return "village_rope_pickup_%s" % get_instance_id()


func _is_interact_event(event: InputEvent) -> bool:
	if event.is_action_pressed("interact"):
		return true
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and (
		key_event.keycode == KEY_E or key_event.physical_keycode == KEY_E
	)


func _find_runtime() -> DayRuntime:
	var current: Node = get_parent()
	while current != null:
		if current is DayRuntime:
			return current
		current = current.get_parent()
	return null
