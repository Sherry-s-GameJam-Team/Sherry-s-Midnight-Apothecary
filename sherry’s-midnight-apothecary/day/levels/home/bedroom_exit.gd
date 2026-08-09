class_name BedroomExit
extends Area2D

## Crossing the bedroom's right edge returns the player to the bedroom door in Home.

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not (body is CharacterBody2D and body.name == "Player"):
		return
	var runtime := _find_day_runtime()
	if runtime != null:
		if runtime.switch_to_level("home", &"bedroomdoor"):
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
