class_name HerbInteractable
extends Area2D

signal collected(ingredient_id: StringName, amount: int)

@export var ingredient_id: StringName = &"herdsmans_loaf_bush"
@export var herb_name := ""
@export var interaction_hint_text := "按[E]采集"
@export var collect_amount := 1
@export var auto_remove_after_collect := true

@onready var visual: Node2D = get_node_or_null("Visual")

var _player: CharacterBody2D
var _player_inside := false


func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_resolve_herb_metadata()


func _exit_tree() -> void:
	if _player_inside:
		_hide_interaction_hint()


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().has_meta("day_modal_input_locked") or not _player_inside or not _is_interact_event(event):
		return
	get_viewport().set_input_as_handled()
	_collect_herb()


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and (body.name == "Player" or body.is_in_group("player")):
		_player = body
		_player_inside = true
		_show_interaction_hint()


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player_inside = false
		_hide_interaction_hint()
		_player = null


func _collect_herb() -> void:
	if ingredient_id == &"":
		push_error("HerbInteractable requires an ingredient_id.")
		return
		
	var player_data := _find_player_data()
	if player_data == null:
		push_warning("HerbInteractable could not find shared PlayerData; inventory was not updated.")
		return
		
	var current_count := int(player_data.inventory.get(ingredient_id, 0))
	var next_count: int = current_count + maxi(collect_amount, 1)
	player_data.inventory[ingredient_id] = next_count
	collected.emit(ingredient_id, next_count - current_count)
	
	var display_name := _resolved_herb_name()
	var app_root := _find_app_root()
	if app_root != null:
		var top_hint := app_root.get_node_or_null("GlobalUI/TopHintUI") as TopHintUI
		if top_hint != null:
			top_hint.push_text("已采集：%s（%s）" % [display_name, next_count], "herb_collected_%s" % get_instance_id(), 1.8)
			
	if auto_remove_after_collect:
		_hide_interaction_hint()
		monitoring = false
		collision_layer = 0
		collision_mask = 0
		visible = false
		queue_free()


func _is_interact_event(event: InputEvent) -> bool:
	if event.is_echo():
		return false
		
	if event.is_action_pressed("interact"):
		return true
		
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and (
		key_event.keycode == KEY_E or key_event.physical_keycode == KEY_E
	)


func _find_app_root() -> Node:
	var current: Node = self
	while current != null:
		if current.get_node_or_null("GlobalUI/TopHintUI") != null:
			return current
		current = current.get_parent()
		
	if is_inside_tree() and get_tree() != null:
		return get_tree().root
	return null


func _find_player_data() -> PlayerData:
	var current: Node = self
	while current != null:
		if current.has_method("get_player_data"):
			return current.call("get_player_data") as PlayerData
		current = current.get_parent()
	return null


func _find_ingredient_data() -> IngredientData:
	var current: Node = self
	while current != null:
		if current.has_method("ingredient_by_id"):
			return current.call("ingredient_by_id", ingredient_id) as IngredientData
		current = current.get_parent()
		
	if ingredient_id == &"":
		return null
		
	var resource_path := "res://shared/definitions/data/ingredients/%s.tres" % ingredient_id
	if ResourceLoader.exists(resource_path):
		return load(resource_path) as IngredientData
	return null


func _resolve_herb_metadata() -> void:
	if ingredient_id == &"":
		return
		
	if herb_name.is_empty():
		var ingredient_data := _find_ingredient_data()
		if ingredient_data != null and not ingredient_data.display_name.is_empty():
			herb_name = ingredient_data.display_name
			if visual is Sprite2D and ingredient_data.preview_texture != null:
				(visual as Sprite2D).texture = ingredient_data.preview_texture
		else:
			herb_name = str(ingredient_id).replace("_", " ")


func _resolved_herb_name() -> String:
	if not herb_name.is_empty():
		return herb_name
	_resolve_herb_metadata()
	if not herb_name.is_empty():
		return herb_name
	return str(ingredient_id).replace("_", " ")


func _show_interaction_hint() -> void:
	var app_root := _find_app_root()
	if app_root == null:
		return
	var top_hint := app_root.get_node_or_null("GlobalUI/TopHintUI") as TopHintUI
	if top_hint == null:
		return
		
	var hint_text := interaction_hint_text
	var resolved_name := _resolved_herb_name()
	if not resolved_name.is_empty():
		hint_text = "%s：%s" % [interaction_hint_text, resolved_name]
	top_hint.show_interaction_hint(_hint_id(), hint_text)


func _hide_interaction_hint() -> void:
	var app_root := _find_app_root()
	if app_root == null:
		return
	var top_hint := app_root.get_node_or_null("GlobalUI/TopHintUI") as TopHintUI
	if top_hint != null:
		top_hint.hide_interaction_hint(_hint_id())


func _hint_id() -> String:
	return "interaction_%s" % get_instance_id()
