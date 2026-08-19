class_name HelionClockSectorWarning
extends Node2D

signal drops_finished

var clock_mark_drop_scene: PackedScene
var _active_drops: int = 0

func execute_drop_attack(target_positions: Array[Vector2], damage: int) -> void:
	if target_positions.is_empty():
		drops_finished.emit()
		return
		
	_active_drops = target_positions.size()
	
	for pos in target_positions:
		if clock_mark_drop_scene:
			var drop = clock_mark_drop_scene.instantiate()
			add_child(drop)
			if drop.has_signal("finished"):
				drop.finished.connect(_on_drop_finished.bind(drop))
			if drop.has_method("spawn"):
				drop.spawn(pos, damage)
		else:
			_on_drop_finished(null)

func execute_random_drops(count: int, arena_rect: Rect2, damage: int) -> void:
	var positions: Array[Vector2] = []
	for i in range(count):
		var rx = randf_range(arena_rect.position.x, arena_rect.position.x + arena_rect.size.x)
		var ry = arena_rect.position.y + arena_rect.size.y # Arena floor
		positions.append(Vector2(rx, ry))
		
	execute_drop_attack(positions, damage)

func _on_drop_finished(drop_node: Node) -> void:
	if is_instance_valid(drop_node):
		drop_node.queue_free()
		
	_active_drops -= 1
	if _active_drops <= 0:
		drops_finished.emit()
