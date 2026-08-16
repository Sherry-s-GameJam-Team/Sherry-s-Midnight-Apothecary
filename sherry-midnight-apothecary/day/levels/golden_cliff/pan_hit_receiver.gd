extends Area2D

@export var side: StringName = &"left"
var mechanism: Node = null

func _ready() -> void:
	if has_meta("side"):
		side = get_meta("side")

func receive_potion_hit(hit: Dictionary) -> void:
	var mech := mechanism
	if mech == null:
		var current: Node = get_parent()
		while current != null:
			if current.has_method("add_weight"):
				mech = current
				break
			current = current.get_parent()
	
	if mech != null and mech.has_method("add_weight"):
		mech.add_weight(side, hit.get("impact_point", global_position))

func apply_potion_effect(_effect_id: StringName, _context: Dictionary) -> void:
	pass
