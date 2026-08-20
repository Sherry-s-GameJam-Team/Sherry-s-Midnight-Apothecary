class_name BedroomExit
extends Area2D

## Crossing the bedroom's right edge returns the player to the bedroom door in Home.

const STICK_READ_FLAG := "bedroom_stick_read"

@export var locked_hint_text := "床头柜上贴着某张便签，先读读看吧"

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if not (body is CharacterBody2D and body.name == "Player"):
		return
	if not _can_exit():
		_show_locked_hint()
		return
	_hide_locked_hint()
	var runtime := _find_day_runtime()
	if runtime != null:
		if bool(runtime.call("switch_to_level", "home", &"bedroomdoor")):
			_place_player_at_home_bedroom_door(runtime.get("current_level_instance") as Node)
	else:
		var tree := get_tree()
		tree.change_scene_to_file("res://day/levels/home/home.tscn")
		tree.process_frame.connect(func() -> void:
			var home := tree.current_scene
			if home == null:
				return
			var entry := home.get_node_or_null("EntryPoints/bedroomdoor") as Marker2D
			var player := home.get_node_or_null("Player") as CharacterBody2D
			if entry != null and player != null:
				player.global_position = entry.global_position
			, CONNECT_ONE_SHOT)


func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and body.name == "Player":
		_hide_locked_hint()


func _can_exit() -> bool:
	var runtime := _find_day_runtime()
	if runtime == null:
		return false
	var player_data := runtime.call("get_player_data") as PlayerData
	return player_data != null and bool(player_data.tutorial_flags.get(STICK_READ_FLAG, false))


func _show_locked_hint() -> void:
	var top_hint := _find_top_hint()
	if top_hint != null:
		top_hint.show_interaction_hint(_hint_id(), locked_hint_text)


func _hide_locked_hint() -> void:
	var top_hint := _find_top_hint()
	if top_hint != null:
		top_hint.hide_interaction_hint(_hint_id())


func _find_top_hint() -> TopHintUI:
	var current: Node = self
	while current != null:
		var top_hint := current.get_node_or_null("GlobalUI/TopHintUI") as TopHintUI
		if top_hint != null:
			return top_hint
		current = current.get_parent()
	return get_tree().root.find_child("TopHintUI", true, false) as TopHintUI


func _hint_id() -> String:
	return "bedroom_exit_locked_%s" % get_instance_id()


func _find_day_runtime() -> Node:
	var current: Node = get_parent()
	while current != null:
		if current.has_method("switch_to_level"):
			return current
		current = current.get_parent()
	return null


func _place_player_at_home_bedroom_door(home: Node) -> void:
	if home == null:
		return
	var entry := home.get_node_or_null("EntryPoints/bedroomdoor") as Marker2D
	var player := home.get_node_or_null("Player") as CharacterBody2D
	if entry != null and player != null:
		player.global_position = entry.global_position
