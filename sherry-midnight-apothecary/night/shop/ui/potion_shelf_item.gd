class_name PotionShelfItem
extends Button

signal potion_hovered(potion: PotionData, instance: Dictionary, price: int)

@onready var bottle_visual: PotionBottleVisual = %BottleVisual
var _base_position := Vector2.ZERO


func show_potion(potion: PotionData, instance: Dictionary, price: int) -> void:
	if bottle_visual == null:
		return
	bottle_visual.show_instance(potion, instance)
	mouse_entered.connect(func() -> void: _show_hover(potion, instance, price))
	mouse_exited.connect(_hide_hover)


func _show_hover(potion: PotionData, instance: Dictionary, price: int) -> void:
	_base_position = bottle_visual.position
	bottle_visual.position = _base_position + Vector2(0, -12)
	bottle_visual.modulate = Color(1.18, 1.18, 1.18, 1.0)
	potion_hovered.emit(potion, instance, price)


func _hide_hover() -> void:
	bottle_visual.position = _base_position
	bottle_visual.modulate = Color.WHITE
