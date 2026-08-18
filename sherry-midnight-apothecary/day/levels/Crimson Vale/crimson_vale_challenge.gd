class_name CrimsonValeChallenge
extends DayLevelEnvironment

signal objective_updated(text: String, hint: String)
signal challenge_completed
signal secret_found

@export var level_title: String = "绯红绝谷·血叶断崖"
@export var fall_damage: int = 1

@onready var danxin_gate_portal: DoorPortal = get_node_or_null("World/DanxinGate/GatePortal")
@onready var exit_portal: DoorPortal = get_node_or_null("ExitPortal")
@onready var wind_chime: Node2D = get_node_or_null("World/Props/WindChimeSecret")
@onready var abyss_hazard: Area2D = get_node_or_null("World/AbyssHazard")
@onready var player_node: CharacterBody2D = get_node_or_null("Player")

var _last_checkpoint_pos: Vector2 = Vector2(250, 520)
var _is_respawning: bool = false


func _ready() -> void:
	super._ready()
	_setup_shelters()
	_setup_abyss_hazard()
	_setup_secrets()


func on_level_entered(entry_id: StringName) -> void:
	match String(entry_id):
		"challenge_start", "default", _:
			objective_updated.emit("穿越血叶疾舞的赤染断崖。", "利用前景掩体躲避血叶群锁定，抵达到达终点的丹心门。")


func _setup_shelters() -> void:
	var shelters := get_tree().get_nodes_in_group("foreground_shelter")
	for shelter in shelters:
		if shelter is ForegroundShelter and not shelter.shelter_entered.is_connected(_on_shelter_entered):
			shelter.shelter_entered.connect(_on_shelter_entered)


func _setup_abyss_hazard() -> void:
	if abyss_hazard != null and not abyss_hazard.body_entered.is_connected(_on_abyss_body_entered):
		abyss_hazard.body_entered.connect(_on_abyss_body_entered)


func _setup_secrets() -> void:
	if wind_chime != null:
		if wind_chime.has_signal("player_passed") and not wind_chime.is_connected("player_passed", _on_wind_chime_player_passed):
			wind_chime.connect("player_passed", _on_wind_chime_player_passed)
		elif wind_chime.has_signal("body_entered") and not wind_chime.is_connected("body_entered", _on_wind_chime_body_entered):
			wind_chime.connect("body_entered", _on_wind_chime_body_entered)


func _on_shelter_entered(body: Node2D) -> void:
	if body is CharacterBody2D and (body.name == "Player" or body.is_in_group("player")):
		_last_checkpoint_pos = body.global_position


func _on_abyss_body_entered(body: Node2D) -> void:
	if _is_respawning:
		return
	if body is CharacterBody2D and (body.name == "Player" or body.is_in_group("player")):
		_respawn_player(body as CharacterBody2D)


func _respawn_player(player: CharacterBody2D) -> void:
	_is_respawning = true
	apply_player_damage(fall_damage, &"crimson_abyss_fall")

	# Safe respawn at last shelter checkpoint
	player.velocity = Vector2.ZERO
	player.global_position = _last_checkpoint_pos

	var presentation := player.get_node_or_null("SherryPresentation") as CanvasItem
	if presentation != null:
		var tw := create_tween()
		if tw != null:
			tw.tween_property(presentation, "modulate:a", 0.3, 0.15)
			tw.tween_property(presentation, "modulate:a", 1.0, 0.25)
			tw.tween_callback(func() -> void: _is_respawning = false)
		else:
			_is_respawning = false
	else:
		_is_respawning = false


func _on_wind_chime_player_passed(player: CharacterBody2D) -> void:
	_trigger_wind_chime_secret(player)


func _on_wind_chime_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and (body.name == "Player" or body.is_in_group("player")):
		_trigger_wind_chime_secret(body as CharacterBody2D)


func _trigger_wind_chime_secret(_player: CharacterBody2D) -> void:
	if wind_chime != null and wind_chime.has_method("ring_all"):
		wind_chime.call("ring_all", 7.0)
	secret_found.emit()
