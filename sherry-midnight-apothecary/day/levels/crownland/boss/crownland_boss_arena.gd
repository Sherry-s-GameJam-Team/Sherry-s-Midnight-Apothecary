class_name CrownlandBossArena
extends Node2D
## 阿里特王畿 Boss 竞技场 / Crownland Boss Arena Controller
##
## Mirrors HelionBossArena in responsibility:
##  - Seals arena on battle start
##  - Relays apply_damage_to_player() to parent level
##  - Forwards boss_defeated to level
##  - Provides get_arena_rect()
##  - Manages HUD show/hide
##
## Does NOT modify DayRuntime, switch scenes, save game.

signal boss_started
signal boss_defeated(boss_id: StringName)

@export var boss_path: NodePath = ^"Boss"
@export var director_path: NodePath = ^"BattleDirector"
@export var pillars_path: NodePath = ^"Pillars"
@export var projectile_root_path: NodePath = ^"ProjectileRoot"
@export var warning_root_path: NodePath = ^"WarningRoot"
@export var vfx_root_path: NodePath = ^"VFXRoot"
@export var hud_path: NodePath = ^"BossHealthBar"
@export var player_spawn_path: NodePath = ^"PlayerSpawn"
@export var arena_bounds_path: NodePath = ^"BossArena"

@export var arena_width: float = 1200.0
@export var arena_height: float = 800.0

var is_battle_active: bool = false

var _boss: CrownlandBoss = null
var _director: CrownlandBattleDirector = null
var _hud: Node = null
var _player_spawn: Marker2D = null
var _arena_bounds: StaticBody2D = null
var _end_flash: ColorRect = null
var _end_flash_tween: Tween


func _ready() -> void:
	add_to_group("crownland_arena")

	_boss = get_node_or_null(boss_path) as CrownlandBoss
	_director = get_node_or_null(director_path) as CrownlandBattleDirector
	_hud = get_node_or_null(hud_path)
	_player_spawn = get_node_or_null(player_spawn_path) as Marker2D
	_arena_bounds = get_node_or_null(arena_bounds_path) as StaticBody2D
	_end_flash = get_node_or_null("EndFlashLayer/EndFlash") as ColorRect

	if _boss != null:
		if _boss.has_signal("boss_defeated"):
			_boss.boss_defeated.connect(_on_boss_defeated)
		if _boss.has_signal("phase_changed"):
			_boss.phase_changed.connect(_on_boss_phase_changed)
		if _boss.has_signal("final_purification_started"):
			_boss.final_purification_started.connect(_on_final_purification_started)
		if _boss.has_signal("health_changed") and _hud != null:
			if _hud.has_method("connect_boss"):
				_hud.call("connect_boss", _boss)
	if _hud != null and _hud.has_method("connect_pillars"):
		_hud.call("connect_pillars", get_node_or_null(pillars_path))

	# Arena bounds start unsealed (no collision) — sealed on battle start
	if _arena_bounds != null:
		_arena_bounds.set_collision_layer_value(1, false)


func trigger_boss_battle(player_node: Node2D = null) -> void:
	if is_battle_active:
		return
	is_battle_active = true

	# Find player
	if player_node == null and is_inside_tree():
		var tree := get_tree()
		if tree != null:
			player_node = tree.get_first_node_in_group("player") as Node2D

	# Seal arena
	if _arena_bounds != null:
		_arena_bounds.set_collision_layer_value(1, true)

	# Show HUD
	if _hud != null and _hud.has_method("show_hud"):
		_hud.call("show_hud")

	# Start director
	if _director != null:
		if player_node != null:
			_director._player = player_node
		_director.begin_battle()

	# Start boss
	if _boss != null:
		_boss.begin_battle()

	boss_started.emit()


func _on_boss_defeated(boss_id: StringName) -> void:
	is_battle_active = false

	# Unseal arena
	if _arena_bounds != null:
		_arena_bounds.set_collision_layer_value(1, false)

	# Hide HUD after delay
	if _hud != null and _hud.has_method("hide_hud"):
		_hud.call("hide_hud", 3.5, 1.5)

	boss_defeated.emit(boss_id)


func _on_boss_phase_changed(_phase: int) -> void:
	if _hud != null and _hud.has_method("on_phase_changed"):
			_hud.call("on_phase_changed", _phase)


func _on_final_purification_started() -> void:
	if _end_flash == null:
		return
	if _end_flash_tween != null and _end_flash_tween.is_valid():
		_end_flash_tween.kill()
	_end_flash.color = Color(1.0, 1.0, 1.0, 0.0)
	_end_flash_tween = create_tween()
	if _end_flash_tween != null:
		_end_flash_tween.tween_property(_end_flash, "color:a", 0.85, 1.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


## Called when player dies — resets entire battle.
func on_player_died() -> void:
	if not is_battle_active:
		return
	# Stop director (cleans up all projectiles)
	if _director != null:
		_director.stop_battle()
	# Reset boss
	if _boss != null:
		_boss.reset_battle()
	is_battle_active = false
	# Hide HUD
	if _hud != null and _hud.has_method("hide_hud"):
		_hud.call("hide_hud", 0.0, 0.5)


## Parent-walk damage relay — called by projectile scripts.
## Projectiles provide themselves as `source`; the shared level-health contract
## deliberately accepts a StringName, so normalize at this encounter boundary.
func apply_damage_to_player(amount: int, source: Variant) -> bool:
	var source_id := _source_id(source)
	var p: Node = get_parent()
	while p != null:
		if p.has_method("apply_player_damage"):
			return bool(p.call("apply_player_damage", amount, source_id))
		if p.has_method("apply_fall_or_hazard_damage"):
			p.call("apply_fall_or_hazard_damage", amount, String(source_id))
			return false
		p = p.get_parent()
	return false


func apply_player_damage(amount: int, source: Variant) -> bool:
	return apply_damage_to_player(amount, source)


func _source_id(source: Variant) -> StringName:
	if source is Node:
		return StringName((source as Node).name)
	if source == null:
		return &"crownland_boss"
	return StringName(str(source))


func get_arena_rect() -> Rect2:
	var half_w := arena_width * 0.5
	return Rect2(
		global_position.x - half_w,
		global_position.y - arena_height,
		arena_width,
		arena_height
	)


func show_hint(text: String) -> void:
	if _hud != null:
		if _hud.has_method("show_hint"):
			_hud.call("show_hint", text)
		elif _hud.has_method("set_hint"):
			_hud.call("set_hint", text)


func get_player_spawn_position() -> Vector2:
	if _player_spawn != null:
		return _player_spawn.global_position
	return global_position
