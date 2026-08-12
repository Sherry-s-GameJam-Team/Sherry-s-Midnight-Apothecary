class_name NightBedroomExit
extends Area2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not (body is CharacterBody2D and body.name == "Player"):
		return
	var bedroom := _find_bedroom()
	if bedroom != null:
		bedroom.request_return()


func _find_bedroom() -> NightBedroom:
	var current := get_parent()
	while current != null:
		if current is NightBedroom:
			return current as NightBedroom
		current = current.get_parent()
	return null
