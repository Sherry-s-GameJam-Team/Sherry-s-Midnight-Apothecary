class_name CrimsonValeLevel
extends DayLevelEnvironment

signal objective_updated(text: String, hint: String)
signal gate_restored
signal challenge_completed
signal secret_found

@export var is_gate_repaired := false
@export var fall_damage: int = 1

@onready var danxin_gate_broken: Sprite2D = get_node_or_null("World/DanxinGate/GateBroken")
@onready var danxin_gate_restored: Sprite2D = get_node_or_null("World/DanxinGate/GateRestored")
@onready var gate_portal: DoorPortal = get_node_or_null("World/DanxinGate/GatePortal")
@onready var wind_chime: Node2D = get_node_or_null("World/Village/WindChime")
@onready var maple_rack: Area2D = get_node_or_null("World/Village/MapleRack")
@onready var abyss_hazard: Area2D = get_node_or_null("World/AbyssHazard")
@onready var wind_chime_secret: Node2D = get_node_or_null("World/Props/WindChimeSecret")

var _last_checkpoint_pos: Vector2 = Vector2(6250, 520)
var _is_respawning: bool = false


func _ready() -> void:
	super._ready()
	_update_gate_visuals()
	_setup_wind_chimes()
	_setup_shelters()
	_setup_abyss_hazard()
	if maple_rack != null and not maple_rack.is_connected("body_entered", _on_maple_rack_body_entered):
		maple_rack.body_entered.connect(_on_maple_rack_body_entered)


func on_level_entered(entry_id: StringName) -> void:
	match String(entry_id):
		"gate":
			objective_updated.emit("探索赤染之谷尽头的丹心门。", "检查古老界门的流转状况。")
		"from_village":
			objective_updated.emit("穿行于赤染村落。", "收集散落的枫脂与草药。")
		_:
			objective_updated.emit("踏入赤染之谷。", "沿着枫红溪谷向东探索血叶断崖。")


func set_corrupted(corrupted: bool) -> void:
	super.set_corrupted(corrupted)
	if corrupted:
		is_gate_repaired = false
	_update_gate_visuals()


func set_gate_repaired(repaired: bool) -> void:
	is_gate_repaired = repaired
	_update_gate_visuals()
	if repaired:
		gate_restored.emit()
		var player_data := get_player_data()
		if player_data != null and player_data.tutorial_flags != null:
			player_data.tutorial_flags["crimson_vale_gate_restored"] = true


func _update_gate_visuals() -> void:
	var show_restored := is_gate_repaired or (not is_corrupted() and not start_corrupted)
	var broken := danxin_gate_broken if danxin_gate_broken != null else get_node_or_null("World/DanxinGate/GateBroken") as Sprite2D
	var restored := danxin_gate_restored if danxin_gate_restored != null else get_node_or_null("World/DanxinGate/GateRestored") as Sprite2D
	var portal := gate_portal if gate_portal != null else get_node_or_null("World/DanxinGate/GatePortal") as DoorPortal
	if broken != null:
		broken.visible = not show_restored
	if restored != null:
		restored.visible = show_restored
	if portal != null:
		portal.monitoring = show_restored
		portal.visible = show_restored


func _setup_wind_chimes() -> void:
	if wind_chime != null:
		if wind_chime.has_signal("player_passed") and not wind_chime.is_connected("player_passed", _on_wind_chime_player_passed):
			wind_chime.connect("player_passed", _on_wind_chime_player_passed)
		elif wind_chime.has_signal("body_entered") and not wind_chime.is_connected("body_entered", _on_wind_chime_body_entered):
			wind_chime.connect("body_entered", _on_wind_chime_body_entered)

	if wind_chime_secret != null:
		if wind_chime_secret.has_signal("player_passed") and not wind_chime_secret.is_connected("player_passed", _on_secret_wind_chime_player_passed):
			wind_chime_secret.connect("player_passed", _on_secret_wind_chime_player_passed)


func _setup_shelters() -> void:
	var shelters := get_tree().get_nodes_in_group("foreground_shelter")
	for shelter in shelters:
		if shelter is ForegroundShelter and not shelter.shelter_entered.is_connected(_on_shelter_entered):
			shelter.shelter_entered.connect(_on_shelter_entered)


func _setup_abyss_hazard() -> void:
	if abyss_hazard != null and not abyss_hazard.body_entered.is_connected(_on_abyss_body_entered):
		abyss_hazard.body_entered.connect(_on_abyss_body_entered)


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


func _on_wind_chime_player_passed(_player: CharacterBody2D) -> void:
	_ring_wind_chime()


func _on_secret_wind_chime_player_passed(_player: CharacterBody2D) -> void:
	if wind_chime_secret != null and wind_chime_secret.has_method("ring_all"):
		wind_chime_secret.call("ring_all", 7.0)
	secret_found.emit()


func _on_wind_chime_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.name == "Player":
		_ring_wind_chime()


func _on_maple_rack_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.name == "Player":
		pass


func _ring_wind_chime() -> void:
	if wind_chime != null and wind_chime.has_method("ring_all"):
		wind_chime.call("ring_all", 5.0)
