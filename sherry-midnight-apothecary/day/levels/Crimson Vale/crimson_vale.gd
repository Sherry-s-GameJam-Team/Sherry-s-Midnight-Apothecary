class_name CrimsonValeLevel
extends DayLevelEnvironment

signal objective_updated(text: String, hint: String)
signal gate_restored

@export var is_gate_repaired := false

@onready var danxin_gate_broken: Sprite2D = get_node_or_null("World/DanxinGate/GateBroken")
@onready var danxin_gate_restored: Sprite2D = get_node_or_null("World/DanxinGate/GateRestored")
@onready var gate_portal: DoorPortal = get_node_or_null("World/DanxinGate/GatePortal")
@onready var wind_chime: Area2D = get_node_or_null("World/Village/WindChime")
@onready var maple_rack: Area2D = get_node_or_null("World/Village/MapleRack")

var _wind_chime_tween: Tween


func _ready() -> void:
	super._ready()
	_update_gate_visuals()
	if wind_chime != null and not wind_chime.is_connected("body_entered", _on_wind_chime_body_entered):
		wind_chime.body_entered.connect(_on_wind_chime_body_entered)
	if maple_rack != null and not maple_rack.is_connected("body_entered", _on_maple_rack_body_entered):
		maple_rack.body_entered.connect(_on_maple_rack_body_entered)


func on_level_entered(entry_id: StringName) -> void:
	match String(entry_id):
		"gate":
			objective_updated.emit("探索赤染之谷尽头的丹心门。", "检查古老界门的流转状况。")
		"from_village":
			objective_updated.emit("穿行于赤染村落。", "收集散落的枫脂与草药。")
		_:
			objective_updated.emit("踏入赤染之谷。", "沿着枫红溪谷向前探索。")


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


func _on_wind_chime_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.name == "Player":
		_ring_wind_chime()


func _on_maple_rack_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.name == "Player":
		pass


func _ring_wind_chime() -> void:
	var sprite := get_node_or_null("World/Village/WindChime/Visual") as Sprite2D
	if sprite == null:
		return
	if _wind_chime_tween != null and _wind_chime_tween.is_valid():
		_wind_chime_tween.kill()
	_wind_chime_tween = create_tween()
	_wind_chime_tween.tween_property(sprite, "rotation_degrees", 8.0, 0.15).set_trans(Tween.TRANS_SINE)
	_wind_chime_tween.tween_property(sprite, "rotation_degrees", -6.0, 0.2).set_trans(Tween.TRANS_SINE)
	_wind_chime_tween.tween_property(sprite, "rotation_degrees", 3.0, 0.25).set_trans(Tween.TRANS_SINE)
	_wind_chime_tween.tween_property(sprite, "rotation_degrees", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
