class_name WindChime
extends Node2D

signal chime_struck(part_index: int, strength: float)
signal player_passed(player: CharacterBody2D)

const BELL_SOUND: AudioStream = preload("res://day/levels/Crimson Vale/sound/bell.wav")

@export_group("Physics Tuning")
@export_range(1.0, 25.0, 0.5) var spring_stiffness: float = 12.0
@export_range(0.5, 12.0, 0.1) var damping: float = 4.2
@export_range(0.05, 2.0, 0.05) var player_push_force: float = 0.45
@export_range(0.0, 0.2, 0.005) var ambient_breeze_strength: float = 0.018
@export_range(0.05, 0.8, 0.01) var max_sway_angle_rad: float = 0.28 # ~16 degrees max
@export var enable_ambient_breeze: bool = true

@export_group("Audio")
@export var enable_sound: bool = true
@export_range(0.0, 1.0, 0.05) var sound_volume: float = 0.7

@onready var background_frame: Sprite2D = get_node_or_null("BackgroundFrame")
@onready var chimes_container: Node2D = get_node_or_null("Chimes")

class ChimePiece:
	var id: String = ""
	var index: int = 0
	var anchor: Vector2 = Vector2.ZERO
	var length: float = 400.0
	var width: float = 60.0
	var freq: float = 7.0
	var pitch: float = 1.0
	var node: Node2D = null
	var sprite: Sprite2D = null
	var area: Area2D = null
	var angle: float = 0.0
	var angular_velocity: float = 0.0
	var last_push_time: float = 0.0

var _pieces: Array[ChimePiece] = []
var _overlapping_players: Array[CharacterBody2D] = []
var _prev_player_positions: Dictionary = {}
var _audio_players: Array[AudioStreamPlayer2D] = []
var _last_global_ring_time: float = 0.0


func _ready() -> void:
	add_to_group("wind_chime")
	add_to_group("interactable")
	_initialize_audio_players()
	_initialize_chimes()


func _initialize_audio_players() -> void:
	for i in range(5):
		var player := AudioStreamPlayer2D.new()
		player.stream = BELL_SOUND
		player.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
		player.max_distance = 2400.0
		add_child(player)
		_audio_players.append(player)


func _physics_process(delta: float) -> void:
	var t := float(Time.get_ticks_msec()) / 1000.0
	_clean_overlapping_players()
	_process_player_collisions()

	for piece: ChimePiece in _pieces:
		if piece.node == null:
			continue

		# 1. Restoring gravity spring force (-k * sin(theta))
		var natural_freq := piece.freq * (spring_stiffness / 8.5)
		var spring_accel := - (natural_freq * natural_freq) * sin(piece.angle)

		# 2. Damping force (-c * omega)
		var damping_accel := - damping * piece.angular_velocity

		# 3. Ambient breeze perturbation (gentle and subtle)
		var breeze := 0.0
		if enable_ambient_breeze:
			breeze = ambient_breeze_strength * sin(t * 2.2 + float(piece.index) * 1.1)

		# Integrate motion
		var total_accel := spring_accel + damping_accel + breeze
		piece.angular_velocity += total_accel * delta
		piece.angle += piece.angular_velocity * delta

		# Clamp maximum physical angle for gentle, subtle sway
		piece.angle = clampf(piece.angle, -max_sway_angle_rad, max_sway_angle_rad)

		# Apply rotation to node
		piece.node.rotation = piece.angle


func push_chime(part_index: int, impulse: float) -> void:
	for piece in _pieces:
		if piece.index == part_index or part_index == 0:
			piece.angular_velocity += impulse * 0.3
			piece.angular_velocity = clampf(piece.angular_velocity, -4.5, 4.5)
			_trigger_chime_struck(piece, absf(impulse))


func hit_by_wind(direction: Vector2, strength: float = 400.0) -> void:
	var dir_x := direction.normalized().x
	if is_zero_approx(dir_x):
		dir_x = 1.0
	var impulse_base := (strength / 100.0) * dir_x * 0.6
	for i in range(_pieces.size()):
		var delay_mult := 1.0 + float(i) * 0.1
		_pieces[i].angular_velocity += impulse_base * delay_mult
		_pieces[i].angular_velocity = clampf(_pieces[i].angular_velocity, -4.5, 4.5)
		_trigger_chime_struck(_pieces[i], absf(impulse_base))


func hit_by_explosion(explosion_pos: Vector2, strength: float = 1.0) -> void:
	for piece in _pieces:
		var world_anchor := global_transform * piece.anchor
		var diff := world_anchor.x - explosion_pos.x
		var dir_x := signf(diff)
		if is_zero_approx(dir_x):
			dir_x = 1.0
		var dist := maxf(world_anchor.distance_to(explosion_pos), 40.0)
		var impulse := (dir_x * 3.5 * strength) * (180.0 / dist)
		piece.angular_velocity += impulse
		piece.angular_velocity = clampf(piece.angular_velocity, -4.5, 4.5)
		_trigger_chime_struck(piece, absf(impulse))


func ring_all(strength: float = 1.8) -> void:
	for i in range(_pieces.size()):
		var dir := 1.0 if i % 2 == 0 else -1.0
		_pieces[i].angular_velocity += dir * strength * randf_range(0.8, 1.2)
		_pieces[i].angular_velocity = clampf(_pieces[i].angular_velocity, -4.5, 4.5)
		_trigger_chime_struck(_pieces[i], strength)


func _trigger_chime_struck(piece: ChimePiece, strength: float) -> void:
	chime_struck.emit(piece.index, strength)
	_play_bell_sound(piece, strength)


func _play_bell_sound(piece: ChimePiece, strength: float) -> void:
	if not enable_sound:
		return

	var now := float(Time.get_ticks_msec()) / 1000.0
	if now - piece.last_push_time < 0.12:
		return
	piece.last_push_time = now

	var player := _get_idle_audio_player()
	if player == null:
		return

	player.position = piece.anchor
	player.pitch_scale = piece.pitch * randf_range(0.98, 1.02)
	player.volume_db = linear_to_db(clampf(sound_volume * (0.3 + strength * 0.45), 0.1, 1.2))
	player.play()


func _get_idle_audio_player() -> AudioStreamPlayer2D:
	for p in _audio_players:
		if not p.playing:
			return p
	return _audio_players[0] if not _audio_players.is_empty() else null


func _initialize_chimes() -> void:
	_pieces.clear()

	var config: Array[Dictionary] = [
		{ "id": "p7", "index": 7, "anchor": Vector2(474, 300), "length": 330.0, "width": 66.0, "freq": 8.4, "pitch": 1.25 },
		{ "id": "p4", "index": 4, "anchor": Vector2(632, 300), "length": 558.0, "width": 54.0, "freq": 6.8, "pitch": 0.95 },
		{ "id": "p2", "index": 2, "anchor": Vector2(712, 291), "length": 515.0, "width": 66.0, "freq": 7.1, "pitch": 1.02 },
		{ "id": "p5", "index": 5, "anchor": Vector2(801, 307), "length": 563.0, "width": 87.0, "freq": 6.7, "pitch": 0.92 },
		{ "id": "p3", "index": 3, "anchor": Vector2(856, 291), "length": 586.0, "width": 56.0, "freq": 6.5, "pitch": 0.88 },
		{ "id": "p6", "index": 6, "anchor": Vector2(914, 305), "length": 508.0, "width": 38.0, "freq": 7.2, "pitch": 1.06 },
		{ "id": "p1", "index": 1, "anchor": Vector2(1032, 291), "length": 415.0, "width": 86.0, "freq": 7.8, "pitch": 1.15 },
	]

	if chimes_container == null:
		return

	for info in config:
		var node_name := "Chime_%s" % info["id"]
		var chime_node := chimes_container.get_node_or_null(node_name) as Node2D
		if chime_node == null:
			continue

		var piece := ChimePiece.new()
		piece.id = info["id"]
		piece.index = info["index"]
		piece.anchor = info["anchor"]
		piece.length = info["length"]
		piece.width = info["width"]
		piece.freq = info["freq"]
		piece.pitch = info.get("pitch", 1.0)
		piece.node = chime_node
		piece.sprite = chime_node.get_node_or_null("Sprite2D") as Sprite2D
		piece.area = chime_node.get_node_or_null("Area2D") as Area2D

		if piece.area != null:
			piece.area.body_entered.connect(_on_chime_body_entered.bind(piece))
			piece.area.body_exited.connect(_on_chime_body_exited.bind(piece))

		_pieces.append(piece)


func _on_chime_body_entered(body: Node2D, piece: ChimePiece) -> void:
	if body is CharacterBody2D:
		var player := body as CharacterBody2D
		if not _overlapping_players.has(player):
			_overlapping_players.append(player)
			player_passed.emit(player)
		_apply_player_push(player, piece)


func _on_chime_body_exited(body: Node2D, _piece: ChimePiece) -> void:
	if body is CharacterBody2D:
		_overlapping_players.erase(body as CharacterBody2D)
		_prev_player_positions.erase(body.get_instance_id())


func _process_player_collisions() -> void:
	for player in _overlapping_players:
		if not is_instance_valid(player):
			continue
		for piece in _pieces:
			if piece.area != null and piece.area.overlaps_body(player):
				_apply_player_push(player, piece)


func _apply_player_push(player: CharacterBody2D, piece: ChimePiece) -> void:
	if not is_instance_valid(player) or piece.node == null:
		return

	# Calculate player speed and displacement relative to chime world anchor
	var world_anchor := global_transform * piece.anchor
	var player_pos := player.global_position

	var player_vx := player.velocity.x
	var id := player.get_instance_id()
	if _prev_player_positions.has(id):
		var prev_pos: Vector2 = _prev_player_positions[id]
		var calc_vx := (player_pos.x - prev_pos.x) * 60.0
		if absf(calc_vx) > absf(player_vx):
			player_vx = calc_vx
	_prev_player_positions[id] = player_pos

	var dir_x := signf(player_vx)
	var speed := absf(player_vx)

	# If player is moving, impart speed-based gentle angular impulse
	if speed > 15.0:
		var impulse := (dir_x * (speed / 180.0) * player_push_force)
		piece.angular_velocity += impulse * 0.25
		piece.angular_velocity = clampf(piece.angular_velocity, -3.5, 3.5)
		_trigger_chime_struck(piece, absf(impulse))
	else:
		# Static / slow brushing subtle deflection
		var local_diff := player_pos.x - world_anchor.x
		var target_deflection := clampf(local_diff / maxf(piece.length * 1.5, 120.0), -0.15, 0.15)
		piece.angle = lerpf(piece.angle, target_deflection, 0.1)


func _clean_overlapping_players() -> void:
	var to_remove: Array[CharacterBody2D] = []
	for p in _overlapping_players:
		if not is_instance_valid(p):
			to_remove.append(p)
	for p in to_remove:
		_overlapping_players.erase(p)
