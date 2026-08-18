class_name ForegroundShelter
extends Area2D

signal shelter_entered(body: Node2D)
signal shelter_exited(body: Node2D)

@export var shelter_name: String = "枫影遮蔽"
@export var show_hint: bool = true
@export var dim_player_visual: bool = true
@export_node_path("Sprite2D") var foreground_visual_path: NodePath

var _occupants: Array[Node2D] = []
var _player_original_modulate: Color = Color.WHITE


func _ready() -> void:
	monitoring = true
	monitorable = false
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

	var visual := get_node_or_null(foreground_visual_path) as Sprite2D
	if visual == null:
		visual = get_node_or_null("ForegroundVisual") as Sprite2D
	if visual != null:
		# Ensure foreground shelter visual renders above gameplay and swarms
		visual.z_index = 20


func is_sheltering_player() -> bool:
	for occ in _occupants:
		if is_instance_valid(occ) and _is_player_node(occ):
			return true
	return false


func _on_body_entered(body: Node2D) -> void:
	if not _is_player_node(body):
		return

	if not _occupants.has(body):
		_occupants.append(body)

	body.set_meta("sheltered", true)
	if not body.is_in_group("sheltered"):
		body.add_to_group("sheltered")

	if dim_player_visual:
		_apply_stealth_visual(body, true)

	if show_hint:
		_show_shelter_hint(true)

	shelter_entered.emit(body)


func _on_body_exited(body: Node2D) -> void:
	if not _is_player_node(body):
		return

	_occupants.erase(body)

	# Check if player is still in another shelter area
	var still_sheltered := false
	var tree := get_tree()
	if tree != null:
		var other_shelters := tree.get_nodes_in_group("foreground_shelter")
		for shelter in other_shelters:
			if shelter != self and shelter.has_method("is_sheltering_player") and shelter.call("is_sheltering_player"):
				still_sheltered = true
				break

	if not still_sheltered:
		body.set_meta("sheltered", false)
		if body.is_in_group("sheltered"):
			body.remove_from_group("sheltered")

		if dim_player_visual:
			_apply_stealth_visual(body, false)

		if show_hint:
			_show_shelter_hint(false)

	shelter_exited.emit(body)


func _is_player_node(node: Node) -> bool:
	if node == null:
		return false
	return node.is_in_group("player") or node.is_in_group("potion_friendly") or node.name == "Player" or node is CharacterBody2D


func _apply_stealth_visual(body: Node2D, in_stealth: bool) -> void:
	var presentation := body.get_node_or_null("SherryPresentation") as CanvasItem
	var sprite := body.get_node_or_null("Sprite2D") as CanvasItem
	var target_item := presentation if presentation != null else (sprite if sprite != null else body as CanvasItem)

	if target_item == null:
		return

	var tw := create_tween()
	if tw == null:
		return
	if in_stealth:
		_player_original_modulate = target_item.modulate
		tw.tween_property(target_item, "modulate", Color(0.68, 0.76, 0.92, 0.78), 0.25)
	else:
		tw.tween_property(target_item, "modulate", Color.WHITE, 0.25)


func _show_shelter_hint(in_shelter: bool) -> void:
	var current: Node = self
	var top_hint: TopHintUI = null
	while current != null:
		top_hint = current.get_node_or_null("GlobalUI/TopHintUI") as TopHintUI
		if top_hint != null:
			break
		current = current.get_parent()

	if top_hint != null:
		var hint_id := "shelter_%s" % get_instance_id()
		if in_shelter:
			top_hint.show_interaction_hint(hint_id, "🌿 [%s] 已进入遮蔽，血叶群失去锁定" % shelter_name)
		else:
			top_hint.hide_interaction_hint(hint_id)
