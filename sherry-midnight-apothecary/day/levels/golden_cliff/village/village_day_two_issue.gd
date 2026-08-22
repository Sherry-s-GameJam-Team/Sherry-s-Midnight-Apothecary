class_name VillageDayTwoIssue
extends Node2D

## Day-two village issue gate.  The local scene owns visibility and crossing
## presentation; StoryEventRunner owns the repeat-safe dialogue completion.

const DELIVERY_COMPLETE_FLAG: StringName = &"mew_order_delivered"
const EVENT_ID: StringName = &"village_day_two_down"
const INTERACTION_KEY: StringName = &"village_day_two_down"
const REQUIRED_DAY := 2 # Narrative day two uses internal day 2.
const DELIVERY_HINT := "请先交付订单给顾客"

@onready var mew: MewNPC = $issue_Mews
@onready var idle_loop: AnimatedSprite2D = $Sprite2D/IdleLoop
@onready var down_marker: Marker2D = $down

var _runtime: DayRuntime
var _player: CharacterBody2D
var _previous_player_x := 0.0
var _hint_ui: TopHintUI


func _ready() -> void:
	_runtime = _find_runtime()
	_player = get_tree().get_first_node_in_group("dialogue_lockable") as CharacterBody2D
	if _player == null:
		_player = get_tree().root.find_child("Player", true, false) as CharacterBody2D
	if _runtime == null or _runtime.day != REQUIRED_DAY:
		visible = false
		set_process(false)
		return

	visible = true
	idle_loop.visible = _has_completed_event()
	if _player != null:
		_previous_player_x = _player.global_position.x
	set_process(true)


func _exit_tree() -> void:
	_hide_delivery_hint()


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var current_x := _player.global_position.x
	if _previous_player_x <= down_marker.global_position.x and current_x > down_marker.global_position.x:
		_on_crossed_down_from_left()
	_previous_player_x = current_x


func _on_crossed_down_from_left() -> void:
	if _has_completed_event():
		idle_loop.visible = true
		_hide_delivery_hint()
		return
	if not _has_delivered_order():
		_show_delivery_hint()
		return

	_hide_delivery_hint()
	if _runtime != null and _runtime.dispatch_story_event_interaction(INTERACTION_KEY):
		idle_loop.visible = true


func _has_delivered_order() -> bool:
	var player_data := _runtime.get_player_data() if _runtime != null else null
	return player_data != null and player_data.has_event_flag(DELIVERY_COMPLETE_FLAG)


func _has_completed_event() -> bool:
	var player_data := _runtime.get_player_data() if _runtime != null else null
	return player_data != null and player_data.has_event_flag(StringName("story_event_completed:%s" % EVENT_ID))


func _show_delivery_hint() -> void:
	var hint_ui := _resolve_hint_ui()
	if hint_ui != null:
		hint_ui.show_interaction_hint(_hint_id(), DELIVERY_HINT)


func _hide_delivery_hint() -> void:
	var hint_ui := _resolve_hint_ui()
	if hint_ui != null:
		hint_ui.hide_interaction_hint(_hint_id())


func _resolve_hint_ui() -> TopHintUI:
	if is_instance_valid(_hint_ui):
		return _hint_ui
	_hint_ui = get_tree().root.find_child("TopHintUI", true, false) as TopHintUI
	return _hint_ui


func _hint_id() -> String:
	return "village_day_two_down_%s" % get_instance_id()


func _find_runtime() -> DayRuntime:
	var current: Node = get_parent()
	while current != null:
		if current is DayRuntime:
			return current
		current = current.get_parent()
	return null
