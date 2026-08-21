class_name ForestEnzuoRescueController
extends Node2D

## Day-one Enzuo rescue.  This deliberately owns only the local mechanism: the
## StoryEventRunner owns the durable completion flag and all main forest routes
## remain untouched.

const ACTIVE_DAY := 1
const INTRO_EVENT: StringName = &"day_one_forest_enzuo_intro"
const RESCUE_EVENT: StringName = &"day_one_forest_enzuo_rescued"
const RESCUE_INTERACTION: StringName = &"day_one_forest_enzuo_rescued"
const SOLVED_FLAG: StringName = &"save_enzuo_solved"
const BALLOON_SCENE := preload("res://night/dialogue/apothecary_balloon.tscn")

@export var release_dialogue: DialogueResource
@export_node_path("CharacterBody2D") var player_path: NodePath
@export_node_path("PotionThrower") var thrower_path: NodePath
@export_node_path("Node2D") var hanging_npc_path: NodePath
@export_node_path("ColorRect") var fade_overlay_path: NodePath
@export var interaction_radius := 190.0
@export var cut_radius := 20.0

var _player: CharacterBody2D
var _thrower: PotionThrower
var _hanging_npc: Node2D
var _fade_overlay: ColorRect
var _runtime: Node
var _hint: TopHintUI
var _vines: Array[Dictionary] = []
var _main_vine_line: Line2D
var _landing_leaf: Polygon2D
var _round := 0
var _running := false
var _resolving := false
var _active_projectile: PotionProjectile
var _previous_projectile_position := Vector2.ZERO
var _hint_id := "forest_enzuo_rescue"
var _mechanism_hint_id := "forest_enzuo_throw"


func _ready() -> void:
	_resolve_nodes()
	_build_vines()
	visible = _is_available()
	if _thrower != null:
		_thrower.projectile_spawned.connect(_on_projectile_spawned)
		if _thrower.trajectory_preview != null:
			_thrower.trajectory_preview.preview_updated.connect(_on_preview_updated)
	_set_round_visibility()


func _exit_tree() -> void:
	if _thrower != null:
		_thrower.set_mechanism_mode(false)
	if get_tree() != null and get_tree().has_meta("day_modal_input_locked"):
		get_tree().remove_meta("day_modal_input_locked")


func _process(_delta: float) -> void:
	if not _is_available():
		visible = false
		_hide_hints()
		return
	visible = true
	if _running or _resolving or _player == null:
		return
	if _player.global_position.distance_to(global_position + Vector2(300.0, 380.0)) <= interaction_radius:
		_show_interaction_hint()
	else:
		_hide_interaction_hint()


func _unhandled_input(event: InputEvent) -> void:
	if _running or _resolving or not _is_available() or _player == null:
		return
	if not event.is_action_pressed("interact"):
		return
	if _player.global_position.distance_to(global_position + Vector2(300.0, 380.0)) > interaction_radius:
		return
	_start_rescue()
	get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	if _active_projectile == null or not is_instance_valid(_active_projectile) or _resolving:
		return
	var current := _active_projectile.global_position
	var from := _previous_projectile_position
	_previous_projectile_position = current
	if _segment_hits_danger(from, current):
		_fail_round()
		return
	for vine in _vines:
		if int(vine.round) != _round or bool(vine.cut):
			continue
		if segment_hits_segment_width(from, current, vine.a, vine.b, cut_radius):
			_cut_vine(vine)
	if _round_is_complete():
		_complete_round()


static func should_offer(day: int, intro_complete: bool, solved: bool) -> bool:
	return day == ACTIVE_DAY and intro_complete and not solved


static func round_vine_count(round_index: int) -> int:
	match round_index:
		0, 2:
			return 2
		1:
			return 3
	return 0


## Tests and preview share this continuous, slightly forgiving segment test.
static func segment_hits_segment_width(from: Vector2, to: Vector2, a: Vector2, b: Vector2, radius: float) -> bool:
	if Geometry2D.segment_intersects_segment(from, to, a, b) != null:
		return true
	return _point_segment_distance(from, a, b) <= radius \
		or _point_segment_distance(to, a, b) <= radius \
		or _point_segment_distance(a, from, to) <= radius \
		or _point_segment_distance(b, from, to) <= radius


static func _point_segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var span := b - a
	if span.length_squared() <= 0.001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(span) / span.length_squared(), 0.0, 1.0)
	return point.distance_to(a + span * t)


func _start_rescue() -> void:
	if _thrower == null:
		return
	_running = true
	_hide_interaction_hint()
	_thrower.set_mechanism_mode(true)
	_hint = get_tree().root.find_child("TopHintUI", true, false) as TopHintUI
	if _hint != null:
		_hint.push_text("机关药水不会消耗库存。让轨迹避开恩佐和主藤。", _mechanism_hint_id, false)


func _on_projectile_spawned(projectile: PotionProjectile) -> void:
	if not _running or _thrower == null or not _thrower.is_mechanism_mode():
		return
	_active_projectile = projectile
	_previous_projectile_position = projectile.global_position
	projectile.tree_exiting.connect(_on_projectile_exited.bind(projectile), CONNECT_ONE_SHOT)


func _on_projectile_exited(projectile: PotionProjectile) -> void:
	if _active_projectile == projectile:
		_active_projectile = null


func _on_preview_updated(points: PackedVector2Array) -> void:
	if not _running or _thrower == null or _thrower.trajectory_preview == null:
		return
	var dangerous := false
	for vine in _vines:
		if int(vine.round) == _round and not bool(vine.cut):
			vine.line.default_color = Color(0.87, 1.0, 1.0, 1.0) if _path_hits_vine(points, vine) else Color(0.42, 0.82, 0.39, 1.0)
	for index in range(1, points.size()):
		if _segment_hits_danger(points[index - 1], points[index]):
			dangerous = true
			break
	_thrower.trajectory_preview.set_dangerous(dangerous)


func _path_hits_vine(points: PackedVector2Array, vine: Dictionary) -> bool:
	for index in range(1, points.size()):
		if segment_hits_segment_width(points[index - 1], points[index], vine.a, vine.b, 2.0):
			return true
	return false


func _segment_hits_danger(from: Vector2, to: Vector2) -> bool:
	var origin := global_position
	if _point_segment_distance(origin + Vector2(385.0, 154.0), from, to) <= 48.0:
		return true
	if _point_segment_distance(origin + Vector2(385.0, 220.0), from, to) <= 72.0:
		return true
	return segment_hits_segment_width(from, to, origin + Vector2(385.0, 62.0), origin + Vector2(385.0, 348.0), 25.0)


func _cut_vine(vine: Dictionary) -> void:
	vine.cut = true
	var line: Line2D = vine.line
	if line != null:
		var tween := create_tween()
		tween.tween_property(line, "modulate:a", 0.0, 0.18)
		tween.tween_callback(line.queue_free)


func _round_is_complete() -> bool:
	var count := 0
	for vine in _vines:
		if int(vine.round) == _round and not bool(vine.cut):
			count += 1
	return count == 0


func _complete_round() -> void:
	if _resolving:
		return
	_resolving = true
	_stop_active_projectile()
	_thrower.set_mechanism_mode(false)
	await get_tree().create_timer(0.2).timeout
	if _round == 0:
		await _animate_hanging(Vector2(350.0, 118.0), 0.55)
		_round = 1
	elif _round == 1:
		await _animate_hanging(Vector2(405.0, 168.0), 0.65)
		_round = 2
	else:
		await _finish_rescue()
		return
	_set_round_visibility()
	_resolving = false
	if _thrower != null:
		_thrower.set_mechanism_mode(true)


func _fail_round() -> void:
	if _resolving:
		return
	_resolving = true
	_stop_active_projectile()
	if _thrower != null:
		_thrower.set_mechanism_mode(false)
	if _hint != null:
		_hint.push_text("雪莉：糟了！", "forest_enzuo_failed", true)
	get_tree().set_meta("day_modal_input_locked", true)
	await _fade(1.0, 0.16)
	for vine in _vines:
		if int(vine.round) == _round:
			vine.cut = false
			if vine.line != null:
				vine.line.modulate.a = 1.0
				vine.line.visible = true
	await _fade(0.0, 0.24)
	get_tree().remove_meta("day_modal_input_locked")
	_resolving = false
	if _thrower != null:
		_thrower.set_mechanism_mode(true)


func _finish_rescue() -> void:
	_running = false
	if _hint != null:
		_hint.hide_interaction_hint(_mechanism_hint_id)
	if _thrower != null:
		_thrower.set_mechanism_mode(false)
	if _main_vine_line != null:
		var glow := create_tween()
		glow.tween_property(_main_vine_line, "default_color", Color(0.52, 1.0, 0.46, 1.0), 0.28)
		await glow.finished
	await _animate_hanging(Vector2(385.0, 430.0), 1.2)
	if _main_vine_line != null:
		_main_vine_line.visible = false
	if _landing_leaf != null:
		_landing_leaf.visible = true
	await _play_release_dialogue()
	if _runtime != null and bool(_runtime.call("dispatch_story_event_interaction", RESCUE_INTERACTION)):
		_runtime.connect(&"story_event_completed", _on_story_event_completed, CONNECT_ONE_SHOT)
	else:
		var data := _player_data()
		if data != null:
			data.set_event_flag(SOLVED_FLAG)
		_hide_rescue_node()


func _on_story_event_completed(event_id: StringName) -> void:
	if event_id == RESCUE_EVENT:
		_hide_rescue_node()


func _hide_rescue_node() -> void:
	_hide_hints()
	visible = false
	get_parent().visible = false


func _animate_hanging(target: Vector2, duration: float) -> void:
	if _hanging_npc == null:
		return
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_hanging_npc, "position", target, duration)
	await tween.finished


func _fade(alpha: float, duration: float) -> void:
	if _fade_overlay == null:
		return
	_fade_overlay.visible = true
	_fade_overlay.color.a = 1.0 - alpha if is_zero_approx(_fade_overlay.color.a) else _fade_overlay.color.a
	var tween := create_tween()
	tween.tween_property(_fade_overlay, "color:a", alpha, duration)
	await tween.finished
	if is_zero_approx(alpha):
		_fade_overlay.visible = false


func _play_release_dialogue() -> void:
	if release_dialogue == null:
		return
	var dialogue_manager := get_node_or_null("/root/DialogueManager") as Node
	if dialogue_manager == null or not dialogue_manager.has_method("show_dialogue_balloon_scene"):
		return
	var balloon := dialogue_manager.show_dialogue_balloon_scene(BALLOON_SCENE, release_dialogue, &"release") as Node
	if balloon != null:
		await balloon.tree_exited


func _stop_active_projectile() -> void:
	if _active_projectile != null and is_instance_valid(_active_projectile):
		_active_projectile.queue_free()
	_active_projectile = null


func _set_round_visibility() -> void:
	for vine in _vines:
		if vine.line != null:
			vine.line.visible = int(vine.round) == _round and not bool(vine.cut)


func _show_interaction_hint() -> void:
	if _hint == null:
		_hint = get_tree().root.find_child("TopHintUI", true, false) as TopHintUI
	if _hint != null:
		_hint.show_interaction_hint(_hint_id, "按 E 开始救援")


func _hide_interaction_hint() -> void:
	if _hint != null:
		_hint.hide_interaction_hint(_hint_id)


func _hide_hints() -> void:
	_hide_interaction_hint()
	if _hint != null:
		_hint.hide_interaction_hint(_mechanism_hint_id)


func _is_available() -> bool:
	var data := _player_data()
	return should_offer(_current_day(), _runtime != null and bool(_runtime.call("has_completed_story_event", INTRO_EVENT)), data != null and data.has_event_flag(SOLVED_FLAG))


func _current_day() -> int:
	return int(_runtime.get("day")) if _runtime != null else -1


func _player_data() -> PlayerData:
	return _runtime.call("get_player_data") as PlayerData if _runtime != null else null


func _resolve_nodes() -> void:
	_player = get_node_or_null(player_path) as CharacterBody2D
	_thrower = get_node_or_null(thrower_path) as PotionThrower
	_hanging_npc = get_node_or_null(hanging_npc_path) as Node2D
	_fade_overlay = get_node_or_null(fade_overlay_path) as ColorRect
	var current: Node = get_parent()
	while current != null:
		if current.has_method("get_player_data") and current.has_method("switch_to_level"):
			_runtime = current
			break
		current = current.get_parent()


func _build_vines() -> void:
	_main_vine_line = Line2D.new()
	_main_vine_line.width = 26.0
	_main_vine_line.default_color = Color(0.12, 0.35, 0.18, 1.0)
	_main_vine_line.add_point(Vector2(385.0, 62.0))
	_main_vine_line.add_point(Vector2(385.0, 348.0))
	_main_vine_line.z_index = 4
	add_child(_main_vine_line)
	_landing_leaf = Polygon2D.new()
	_landing_leaf.polygon = PackedVector2Array([Vector2(270.0, 454.0), Vector2(385.0, 402.0), Vector2(500.0, 454.0), Vector2(385.0, 482.0)])
	_landing_leaf.color = Color(0.24, 0.56, 0.23, 0.95)
	_landing_leaf.z_index = 3
	_landing_leaf.visible = false
	add_child(_landing_leaf)
	var definitions := [
		[0, Vector2(270, 225), Vector2(345, 244)], [0, Vector2(448, 128), Vector2(410, 185)],
		[1, Vector2(285, 166), Vector2(348, 204)], [1, Vector2(470, 245), Vector2(414, 266)], [1, Vector2(462, 323), Vector2(412, 294)],
		[2, Vector2(294, 310), Vector2(355, 282)], [2, Vector2(445, 98), Vector2(404, 158)],
	]
	for definition in definitions:
		var line := Line2D.new()
		line.width = 10.0
		line.default_color = Color(0.42, 0.82, 0.39, 1.0)
		line.add_point(definition[1])
		line.add_point(definition[2])
		line.z_index = 6
		add_child(line)
		_vines.append({"round": int(definition[0]), "a": global_position + definition[1], "b": global_position + definition[2], "cut": false, "line": line})
