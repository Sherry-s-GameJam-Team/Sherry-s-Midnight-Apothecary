extends StaticBody2D

var received_effects: Array[StringName] = []
var last_context: Dictionary = {}


func apply_potion_effect(effect_id: StringName, context: Dictionary) -> void:
	received_effects.append(effect_id)
	last_context = context.duplicate(true)

