class_name VesperBossArena
extends DayLevelEnvironment

## Arena controller for Vespervale Hospital Director Boss battle.
## Background: treegarden.png.
## Manages pre-battle intro dialogue, Dream Tide environment effects, victory transitions, and exit unlocking.

signal boss_battle_started
signal boss_battle_ended(victory: bool)

const BALLOON_SCENE := preload("res://night/dialogue/apothecary_balloon.tscn")

@export var intro_dialogue: DialogueResource = preload("res://day/levels/Vespervale/vesper_boss_intro.dialogue")

var is_battle_active: bool = false
var is_victory: bool = false

@onready var boss: VesperDirectorBoss = get_node_or_null("BossRoot/VesperDirectorBoss") as VesperDirectorBoss
@onready var boss_hud: VesperBossHUD = get_node_or_null("UI/VesperBossHUD") as VesperBossHUD
@onready var tide_vignette: ColorRect = get_node_or_null("FXLayer/DreamTideVignette") as ColorRect
@onready var exit_portal: Area2D = get_node_or_null("World/Portals/ExitPortal") as Area2D
@onready var victory_banner: Control = get_node_or_null("UI/VictoryBanner") as Control


func _ready() -> void:
	super._ready()

	if exit_portal != null:
		exit_portal.visible = false
		exit_portal.monitoring = false

	if tide_vignette != null:
		tide_vignette.visible = true
		tide_vignette.modulate.a = 0.0

	if victory_banner != null:
		victory_banner.visible = false

	if boss != null:
		if boss_hud != null:
			boss_hud.setup(boss)
			boss_hud.visible = false
		boss.dream_tide_state_changed.connect(_on_dream_tide_state_changed)
		boss.boss_defeated.connect(_on_boss_defeated)

	call_deferred("_start_intro_sequence")


func _start_intro_sequence() -> void:
	if intro_dialogue != null:
		# Lock player during intro conversation
		_set_player_control(false)

		var dialogue_manager := get_node_or_null("/root/DialogueManager")
		if dialogue_manager != null and dialogue_manager.has_method("show_dialogue_balloon_scene"):
			dialogue_manager.show_dialogue_balloon_scene(BALLOON_SCENE, intro_dialogue, &"start")
			if dialogue_manager.has_signal("dialogue_ended"):
				dialogue_manager.dialogue_ended.connect(_on_intro_dialogue_ended, CONNECT_ONE_SHOT)
			else:
				_start_actual_battle()
		else:
			_start_actual_battle()
	else:
		_start_actual_battle()


func _on_intro_dialogue_ended(_resource: Resource = null) -> void:
	_start_actual_battle()


func _start_actual_battle() -> void:
	_set_player_control(true)

	if boss_hud != null:
		boss_hud.visible = true

	if boss != null:
		boss.start_battle()

	is_battle_active = true
	boss_battle_started.emit()


func _set_player_control(enabled: bool) -> void:
	var player := get_node_or_null("Player")
	if player != null:
		if player.has_method("set_dialogue_locked"):
			player.call("set_dialogue_locked", not enabled)
		elif player.has_method("set_control_enabled"):
			player.call("set_control_enabled", enabled)


func _on_dream_tide_state_changed(is_tide: bool) -> void:
	if tide_vignette != null:
		var target_alpha := 0.42 if is_tide else 0.0
		var tw := create_tween()
		tw.tween_property(tide_vignette, "modulate:a", target_alpha, 0.4)


func _on_boss_defeated() -> void:
	is_victory = true
	is_battle_active = false
	var player_data := get_player_data()
	if player_data != null:
		player_data.set_event_flag(&"vespervale_boss_defeated")
		if player_data.tutorial_flags != null:
			player_data.tutorial_flags["vespervale_boss_cleared"] = true
			player_data.tutorial_flags["vespervale_garden_cleansed"] = true
	boss_battle_ended.emit(true)

	# Lock player controls during victory transition
	_set_player_control(false)

	# Clear active bullets and hazards
	var bullet_layer := get_node_or_null("BulletLayer")
	if bullet_layer != null:
		for child in bullet_layer.get_children():
			child.queue_free()

	var hazard_layer := get_node_or_null("HazardLayer")
	if hazard_layer != null:
		for child in hazard_layer.get_children():
			child.queue_free()

	# Show victory banner & automatically fade to black
	var tw := create_tween()
	if victory_banner != null:
		victory_banner.visible = true
		victory_banner.modulate.a = 0.0
		tw.tween_property(victory_banner, "modulate:a", 1.0, 0.6)
		tw.tween_interval(2.0)
	else:
		tw.tween_interval(1.5)

	var fade_rect: ColorRect = get_node_or_null("UI/TransitionFade") as ColorRect
	if fade_rect != null:
		fade_rect.visible = true
		fade_rect.modulate.a = 0.0
		tw.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
	else:
		tw.tween_interval(0.8)

	tw.finished.connect(_transition_back_to_garden)


func _transition_back_to_garden() -> void:
	var runtime := _find_day_runtime()
	if runtime != null:
		if runtime.has_method("transition_to_level_with_blackout"):
			runtime.call("transition_to_level_with_blackout", "vespervale_garden", &"church", true)
		else:
			runtime.switch_to_level("vespervale_garden", &"church")
		return

	# Standalone fallback:
	get_tree().set_meta("pending_entry_id", &"church")
	get_tree().change_scene_to_file("res://day/levels/Vespervale/garden.tscn")


func _find_day_runtime() -> Node:
	var current: Node = get_parent()
	while current != null:
		if current.has_method("switch_to_level") or current.has_method("finish_day"):
			return current
		current = current.get_parent()
	var root := get_tree().root if get_tree() != null else null
	if root != null:
		return root.find_child("DayRuntime", true, false)
	return null
