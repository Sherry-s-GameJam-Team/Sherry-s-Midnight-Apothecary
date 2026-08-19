class_name RetroClockbird
extends CharacterBody2D

## 齿轮鸟 / 逆行时钟鸟 (Retro Clockbird)
## 使用 res://day/levels/Aurem Clockyard/src/frames/ 24帧序列动画
## 拥有巡逻、警觉瞄准、俯冲掠袭、螺栓发射及冰冻立足点 AI

enum State {
	PATROL,
	AIMING,
	DIVE_ATTACK,
	BARRAGE_ATTACK,
	RECOVER,
	FROZEN,
}

@export var patrol_range: float = 240.0
@export var cruise_speed: float = 90.0
@export var dive_speed: float = 380.0
@export var detection_radius: float = 380.0
@export var contact_damage: int = 12
@export var bolt_damage: int = 8

var _state: State = State.PATROL
var _origin_pos: Vector2
var _target_aim_pos: Vector2
var _dive_start_pos: Vector2
var _dive_bottom_pos: Vector2
var _dive_progress: float = 0.0
var _facing_dir: float = -1.0 # Default leftward retro flight

var _state_timer: float = 0.0
var _attack_cooldown_timer: float = 1.5
var _frozen_timer: float = 0.0
var _flight_time: float = 0.0
var _current_frame_idx: float = 0.0

var _frames: Array[Texture2D] = []

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var hitbox: Area2D = get_node_or_null("Hitbox")
@onready var solid_collision: CollisionShape2D = get_node_or_null("SolidCollision")


func _init() -> void:
	_load_animation_frames()


func _ready() -> void:
	_origin_pos = position
	_load_animation_frames()
	_update_sprite_frame()

	if hitbox != null:
		hitbox.body_entered.connect(_on_hitbox_body_entered)


func _load_animation_frames() -> void:
	if _frames.size() == 24:
		return
	_frames.clear()
	for i in range(24):
		var path := "res://day/levels/Aurem Clockyard/src/frames/frame_%02d.png" % i
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			var tex: Texture2D = load(path)
			if tex != null:
				_frames.append(tex)


func receive_potion_hit(hit: Dictionary) -> void:
	var potion_id: String = String(hit.get("potion_id", ""))
	if "blue" in potion_id or "ice" in potion_id or "cyan" in potion_id:
		_state = State.FROZEN
		_frozen_timer = 4.5
		if sprite != null:
			sprite.modulate = Color(0.4, 0.8, 1.4)
		if solid_collision != null:
			solid_collision.disabled = false
	elif "red" in potion_id or "bomb" in potion_id or "attack" in potion_id:
		_play_defeat_particles()
		queue_free()
	elif "orange" in potion_id or "speed" in potion_id:
		_state = State.RECOVER
		_state_timer = 1.0


func _physics_process(delta: float) -> void:
	if _state == State.FROZEN:
		_frozen_timer -= delta
		if _frozen_timer <= 0.0:
			_state = State.PATROL
			_attack_cooldown_timer = 2.0
			if sprite != null:
				sprite.modulate = Color.WHITE
			if solid_collision != null:
				solid_collision.disabled = true
		return

	_flight_time += delta
	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer -= delta

	match _state:
		State.PATROL:
			_process_patrol(delta)
		State.AIMING:
			_process_aiming(delta)
		State.DIVE_ATTACK:
			_process_dive(delta)
		State.BARRAGE_ATTACK:
			_process_barrage(delta)
		State.RECOVER:
			_process_recover(delta)

	_advance_animation(delta)
	queue_redraw()


func _process_patrol(delta: float) -> void:
	position.x += _facing_dir * cruise_speed * delta

	# Sinusoidal cruising wave
	position.y = _origin_pos.y + sin(_flight_time * 2.5) * 20.0

	# Turn at patrol boundaries
	if absf(position.x - _origin_pos.x) >= patrol_range:
		_facing_dir = -signf(position.x - _origin_pos.x)

	if sprite != null:
		sprite.flip_h = _facing_dir > 0.0

	# Scan for player to initiate attack
	if _attack_cooldown_timer <= 0.0:
		var player := _find_player()
		if player != null:
			var to_player := player.global_position - global_position
			if to_player.length() <= detection_radius and to_player.y > -50.0:
				_start_aiming(player.global_position)


func _start_aiming(player_target: Vector2) -> void:
	_state = State.AIMING
	_state_timer = 0.85
	_target_aim_pos = player_target
	_facing_dir = signf(player_target.x - global_position.x)
	if is_zero_approx(_facing_dir):
		_facing_dir = 1.0

	if sprite != null:
		sprite.flip_h = _facing_dir > 0.0

	if is_inside_tree():
		var tree := get_tree()
		if tree != null:
			var audio: Node = tree.get_first_node_in_group("clocktower_audio")
			if audio != null and audio.has_method("play_bell_warning"):
				audio.call("play_bell_warning", true)


func _process_aiming(delta: float) -> void:
	_state_timer -= delta

	# Hover with slight tension jitter
	position.y = _origin_pos.y + sin(_flight_time * 8.0) * 8.0

	# Track player location while aiming
	var player := _find_player()
	if player != null:
		_target_aim_pos = player.global_position
		_facing_dir = signf(_target_aim_pos.x - global_position.x)
		if is_zero_approx(_facing_dir):
			_facing_dir = 1.0
		if sprite != null:
			sprite.flip_h = _facing_dir > 0.0

	if _state_timer <= 0.0:
		# Decide attack type based on distance
		var dist := global_position.distance_to(_target_aim_pos)
		if dist < 260.0:
			_start_dive_attack()
		else:
			_start_barrage_attack()


func _start_dive_attack() -> void:
	_state = State.DIVE_ATTACK
	_dive_start_pos = position
	_dive_bottom_pos = _target_aim_pos - (get_parent().global_position if get_parent() != null else Vector2.ZERO)
	_dive_progress = 0.0


func _process_dive(delta: float) -> void:
	_dive_progress += (dive_speed / 450.0) * delta
	if _dive_progress < 0.5:
		# Swoop down towards player
		var t := _dive_progress * 2.0
		position = _dive_start_pos.lerp(_dive_bottom_pos, t * t)
	elif _dive_progress < 1.0:
		# Swoop back up to cruise altitude on opposite side
		var t := (_dive_progress - 0.5) * 2.0
		var ascend_target := Vector2(_dive_bottom_pos.x + _facing_dir * 180.0, _origin_pos.y)
		position = _dive_bottom_pos.lerp(ascend_target, 1.0 - (1.0 - t) * (1.0 - t))
	else:
		_drop_bolt(Vector2.ZERO)
		_state = State.RECOVER
		_state_timer = 0.6
		_attack_cooldown_timer = 3.2


func _start_barrage_attack() -> void:
	_state = State.BARRAGE_ATTACK
	_state_timer = 0.6
	_drop_bolt(Vector2(_facing_dir * 80.0, 220.0))
	_drop_bolt(Vector2(_facing_dir * 20.0, 240.0))


func _process_barrage(delta: float) -> void:
	_state_timer -= delta
	if _state_timer <= 0.0:
		_state = State.RECOVER
		_state_timer = 0.8
		_attack_cooldown_timer = 3.0


func _process_recover(delta: float) -> void:
	_state_timer -= delta
	# Smoothly return to cruising height
	position.y = move_toward(position.y, _origin_pos.y, 140.0 * delta)
	if _state_timer <= 0.0:
		_state = State.PATROL


func _advance_animation(delta: float) -> void:
	if _frames.is_empty():
		return

	var fps := 12.0
	match _state:
		State.PATROL:
			fps = 12.0
		State.AIMING:
			fps = 22.0
		State.DIVE_ATTACK:
			fps = 24.0
		State.BARRAGE_ATTACK:
			fps = 18.0
		State.RECOVER:
			fps = 10.0
		State.FROZEN:
			fps = 0.0

	_current_frame_idx += fps * delta
	if _current_frame_idx >= _frames.size():
		_current_frame_idx = fmod(_current_frame_idx, float(_frames.size()))

	_update_sprite_frame()


func _update_sprite_frame() -> void:
	if sprite != null and not _frames.is_empty():
		var idx := int(_current_frame_idx) % _frames.size()
		sprite.texture = _frames[idx]


func _draw() -> void:
	# Draw telegraph beam when aiming
	if _state == State.AIMING:
		var local_target := to_local(_target_aim_pos)
		var pulse := (sin(_flight_time * 16.0) + 1.0) * 0.5
		var color := Color(1.0, 0.3, 0.1, 0.4 + 0.4 * pulse)
		draw_line(Vector2.ZERO, local_target, color, 2.5)
		draw_circle(local_target, 12.0 + 4.0 * pulse, Color(1.0, 0.2, 0.1, 0.5))


const GEAR_BOLT_TEXTURE_PATH := "res://day/levels/Aurem Clockyard/src/gear.png"

func _drop_bolt(aim_velocity: Vector2 = Vector2.ZERO) -> void:
	var bolt := Area2D.new()
	bolt.collision_layer = 0
	bolt.collision_mask = 1 | 2

	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	col.shape = circle
	bolt.add_child(col)

	var spr := Sprite2D.new()
	if ResourceLoader.exists(GEAR_BOLT_TEXTURE_PATH) or FileAccess.file_exists(GEAR_BOLT_TEXTURE_PATH):
		spr.texture = load(GEAR_BOLT_TEXTURE_PATH)
		spr.scale = Vector2(0.45, 0.45)
	elif not _frames.is_empty():
		spr.texture = _frames[0]
		spr.scale = Vector2(0.3, 0.3)
	spr.modulate = Color(1.2, 0.85, 0.3)
	bolt.add_child(spr)

	var parent := get_parent()
	if parent != null:
		parent.add_child(bolt)
	else:
		add_child(bolt)

	bolt.global_position = global_position

	bolt.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("player") or b.name == "Player":
			if is_inside_tree():
				var tree := get_tree()
				if tree != null:
					var env := tree.get_first_node_in_group("clocktower_inside")
					if env != null and env.has_method("apply_fall_or_hazard_damage"):
						env.call("apply_fall_or_hazard_damage", bolt_damage, "clockbird_bolt")
			bolt.queue_free()
		elif b is StaticBody2D or b is AnimatableBody2D:
			bolt.queue_free()
	)

	var tween := bolt.create_tween()
	var target_fall := bolt.position + Vector2(aim_velocity.x, maxf(aim_velocity.y, 350.0))
	if tween != null:
		tween.set_parallel(true)
		tween.tween_property(bolt, "position", target_fall, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(spr, "rotation", TAU * 3.0 * (1.0 if aim_velocity.x >= 0.0 else -1.0), 1.2)
		tween.chain().tween_callback(bolt.queue_free)


func _on_hitbox_body_entered(body: Node2D) -> void:
	if _state == State.FROZEN:
		return
	if body.is_in_group("player") or body.name == "Player":
		if is_inside_tree():
			var tree := get_tree()
			if tree != null:
				var audio: Node = tree.get_first_node_in_group("clocktower_audio")
				if audio != null and audio.has_method("play_gear_grind_warning"):
					audio.call("play_gear_grind_warning")
				var env := tree.get_first_node_in_group("clocktower_inside")
				if env != null and env.has_method("apply_fall_or_hazard_damage"):
					env.call("apply_fall_or_hazard_damage", contact_damage, "clockbird_dive")


func _find_player() -> Node2D:
	if is_inside_tree():
		var tree := get_tree()
		if tree != null:
			var player := tree.get_first_node_in_group("player")
			if player != null and player is Node2D:
				return player as Node2D
			var root_player := tree.root.find_child("Player", true, false)
			if root_player != null and root_player is Node2D:
				return root_player as Node2D
	return null


func _play_defeat_particles() -> void:
	if is_inside_tree():
		var tree := get_tree()
		if tree != null:
			var audio: Node = tree.get_first_node_in_group("clocktower_audio")
			if audio != null and audio.has_method("play_spring_pulse"):
				audio.call("play_spring_pulse")
