class_name HelionClockFloorController extends Node2D

signal round_finished
signal final_tolls_finished

enum SectorState { NORMAL, WARNING, RETRACTED, RESTORING }

var _sector_states: Array[SectorState] = []
var _sector_nodes: Array[StaticBody2D] = []
var _sector_original_positions: Array[Vector2] = []
var _warning_tweens: Array[Tween] = []
var _sector_tweens: Array[Tween] = []

func _ready() -> void:
	_sector_states.resize(12)
	_sector_nodes.resize(12)
	_sector_original_positions.resize(12)
	_warning_tweens.resize(12)
	_sector_tweens.resize(12)
	
	for i in range(12):
		_sector_states[i] = SectorState.NORMAL
		var sector_name = "Sector%02d" % (i + 1)
		var child = get_node_or_null(sector_name) as StaticBody2D
		_sector_nodes[i] = child
		if child:
			_sector_original_positions[i] = child.position

func warn_sectors(indices: Array[int]) -> void:
	for index in indices:
		if index < 0 or index >= 12: continue
		if not _sector_nodes[index]: continue
		
		_sector_states[index] = SectorState.WARNING
		
		if _warning_tweens[index] and _warning_tweens[index].is_valid():
			_warning_tweens[index].kill()
		
		var sprite = _get_sprite(index)
		if sprite:
			_warning_tweens[index] = create_tween().set_loops()
			_warning_tweens[index].tween_property(sprite, "modulate", Color(1.0, 0.5, 0.0, 1.0), 0.2)
			_warning_tweens[index].tween_property(sprite, "modulate", Color.WHITE, 0.2)

func retract_sectors(indices: Array[int]) -> void:
	for index in indices:
		if index < 0 or index >= 12: continue
		var node = _sector_nodes[index]
		if not node: continue
		
		_sector_states[index] = SectorState.RETRACTED
		
		if _warning_tweens[index] and _warning_tweens[index].is_valid():
			_warning_tweens[index].kill()
		
		var sprite = _get_sprite(index)
		if sprite:
			sprite.modulate = Color.WHITE
			
		var col = _get_collision(index)
		if col:
			col.set_deferred("disabled", true)
			
		if _sector_tweens[index] and _sector_tweens[index].is_valid():
			_sector_tweens[index].kill()
			
		var target_y = _sector_original_positions[index].y + 200.0
		_sector_tweens[index] = create_tween()
		_sector_tweens[index].tween_property(node, "position:y", target_y, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

func restore_sectors(indices: Array[int]) -> void:
	for index in indices:
		if index < 0 or index >= 12: continue
		var node = _sector_nodes[index]
		if not node: continue
		
		_sector_states[index] = SectorState.RESTORING
		
		if _warning_tweens[index] and _warning_tweens[index].is_valid():
			_warning_tweens[index].kill()
			
		var sprite = _get_sprite(index)
		if sprite:
			sprite.modulate = Color.WHITE
			
		var col = _get_collision(index)
		if col:
			col.set_deferred("disabled", false)
			
		if _sector_tweens[index] and _sector_tweens[index].is_valid():
			_sector_tweens[index].kill()
			
		_sector_tweens[index] = create_tween()
		_sector_tweens[index].tween_property(node, "position", _sector_original_positions[index], 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_sector_tweens[index].tween_callback(func(): _sector_states[index] = SectorState.NORMAL)

func restore_all() -> void:
	var all_indices: Array[int] = []
	for i in range(12):
		all_indices.append(i)
	restore_sectors(all_indices)

func _get_sprite(index: int) -> Sprite2D:
	var node = _sector_nodes[index]
	if node:
		for child in node.get_children():
			if child is Sprite2D:
				return child
	return null

func _get_collision(index: int) -> CollisionShape2D:
	var node = _sector_nodes[index]
	if node:
		for child in node.get_children():
			if child is CollisionShape2D:
				return child
	return null

func execute_round_1(warning_time: float, retract_time: float) -> void:
	var proposed: Array[int] = []
	while proposed.size() < 4:
		var r = randi() % 12
		if not r in proposed:
			proposed.append(r)
	
	proposed = _ensure_safe_sectors(proposed)
	warn_sectors(proposed)
	await get_tree().create_timer(warning_time).timeout
	retract_sectors(proposed)
	await get_tree().create_timer(retract_time).timeout
	restore_sectors(proposed)
	await get_tree().create_timer(0.5).timeout
	round_finished.emit()

func execute_round_2(warning_time: float, retract_time: float) -> void:
	var proposed: Array[int] = []
	var is_odd = randi() % 2 == 0
	for i in range(12):
		if (i % 2 == 0) == is_odd:
			proposed.append(i)
			
	proposed = _ensure_safe_sectors(proposed)
	warn_sectors(proposed)
	await get_tree().create_timer(warning_time).timeout
	retract_sectors(proposed)
	await get_tree().create_timer(retract_time).timeout
	restore_sectors(proposed)
	await get_tree().create_timer(0.5).timeout
	round_finished.emit()

func execute_round_3(warning_time: float, retract_time: float) -> void:
	var proposed: Array[int] = []
	var start = randi() % 12
	for i in range(3):
		proposed.append((start + i) % 12)
		
	proposed = _ensure_safe_sectors(proposed)
	warn_sectors(proposed)
	await get_tree().create_timer(warning_time).timeout
	retract_sectors(proposed)
	await get_tree().create_timer(retract_time).timeout
	restore_sectors(proposed)
	await get_tree().create_timer(0.5).timeout
	round_finished.emit()

func _ensure_safe_sectors(proposed: Array[int]) -> Array[int]:
	# We want at least 3 consecutive safe sectors.
	var result = proposed.duplicate()
	var safe: Array[int] = []
	for i in range(12):
		if not i in result:
			safe.append(i)
			
	var max_consecutive = 0
	var current_consecutive = 0
	for i in range(24):
		var idx = i % 12
		if idx in safe:
			current_consecutive += 1
			if current_consecutive > max_consecutive:
				max_consecutive = current_consecutive
		else:
			current_consecutive = 0
			
	if max_consecutive >= 3:
		return result
		
	# Force indices 0, 1, 2 to be safe as fallback
	var fallback_safe = [0, 1, 2]
	var fallback_result: Array[int] = []
	for p in result:
		if not p in fallback_safe:
			fallback_result.append(p)
			
	return fallback_result

func run_final_twelve_tolls(toll_duration: float, toll_interval: float) -> void:
	for i in range(12):
		var retracting: Array[int] = []
		var restoring: Array[int] = []
		for j in range(12):
			if randf() > 0.5:
				retracting.append(j)
			else:
				restoring.append(j)
		
		retracting = _ensure_safe_sectors(retracting)
		
		# Sequentially light up toll sector
		if not i in retracting:
			warn_sectors([i])
		else:
			warn_sectors(retracting)
			
		restore_sectors(restoring)
		
		await get_tree().create_timer(toll_interval).timeout
		retract_sectors(retracting)
		
	var final_retract: Array[int] = []
	for j in range(12):
		if randf() > 0.3:
			final_retract.append(j)
			
	final_retract = _ensure_safe_sectors(final_retract)
	warn_sectors(final_retract)
	await get_tree().create_timer(toll_interval).timeout
	retract_sectors(final_retract)
	
	final_tolls_finished.emit()

func is_sector_safe(index: int) -> bool:
	if index < 0 or index >= 12: return false
	var state = _sector_states[index]
	return state == SectorState.NORMAL or state == SectorState.RESTORING

func get_safe_sector_positions() -> Array[Vector2]:
	var safe_pos: Array[Vector2] = []
	for i in range(12):
		if is_sector_safe(i) and _sector_nodes[i]:
			safe_pos.append(_sector_original_positions[i])
	return safe_pos
