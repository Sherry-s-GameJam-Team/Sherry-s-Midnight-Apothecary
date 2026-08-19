class_name DreamThornBed
extends StaticBody2D

## Dream Bed Platform:
## In Reality Intrusion: completely disappears along with its collision box.
## In Dream state: solidifies into a safe, walkable dream platform with original clean sprite colors.

var _is_dream: bool = false

@onready var bed_sprite: Sprite2D = get_node_or_null("BedSprite")
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var thorn_hazard: Area2D = get_node_or_null("ThornHazard")


func _ready() -> void:
	if thorn_hazard != null:
		var col := thorn_hazard.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if col != null:
			col.disabled = true
		thorn_hazard.queue_free()

	if bed_sprite != null:
		bed_sprite.modulate = Color.WHITE

	var manager := _find_shift_manager()
	if manager != null:
		manager.dream_state_changed.connect(_on_dream_state_changed)
		_set_dream_state(manager.is_in_dream(), false)
	else:
		_set_dream_state(false, false)


func _on_dream_state_changed(in_dream: bool) -> void:
	_set_dream_state(in_dream, true)


func _set_dream_state(in_dream: bool, animate: bool) -> void:
	_is_dream = in_dream

	# In Reality: collision disabled; In Dream: collision enabled
	if collision_shape != null:
		collision_shape.set_deferred("disabled", not in_dream)

	collision_layer = (1 | 2) if in_dream else 0

	if animate:
		if in_dream:
			visible = true
			if bed_sprite != null:
				bed_sprite.modulate = Color.WHITE
			var tw := create_tween()
			tw.tween_property(self, "modulate:a", 1.0, 0.3)
		else:
			var tw := create_tween()
			tw.tween_property(self, "modulate:a", 0.0, 0.3)
			tw.tween_callback(func() -> void:
				if not _is_dream:
					visible = false
			)
	else:
		visible = in_dream
		modulate.a = 1.0 if in_dream else 0.0
		if bed_sprite != null:
			bed_sprite.modulate = Color.WHITE


func _find_shift_manager() -> DreamShiftManager:
	var cur: Node = self
	while cur != null:
		var mgr := cur.get_node_or_null("DreamShiftManager") as DreamShiftManager
		if mgr != null:
			return mgr
		cur = cur.get_parent()
	return null
