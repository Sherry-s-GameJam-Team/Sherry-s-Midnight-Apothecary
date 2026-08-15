class_name CliffResonanceLevel
extends DayLevelEnvironment

signal level_cleared

const CLEAR_FLAG := "cliff_resonance_cleared"

@export var respawn_position := Vector2(260.0, 470.0)
@export var fade_out_time := 0.16
@export var fade_in_time := 0.24
## Optional: set this to an existing LevelData id if the receiver should immediately transition elsewhere.
@export var completion_level_id := ""
@export var completion_entry_id: StringName = &"default"

@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var player: CharacterBody2D = $Player
@onready var fade_rect: ColorRect = $UI/FadeRect
@onready var progress_label: Label = $UI/ProgressLabel
@onready var complete_label: Label = $UI/CompleteLabel
@onready var receiver: CliffResonanceReceiver = $Mechanisms/ResonanceReceiver
@onready var hazard_controller: CliffHazardController = $Hazards/CliffHazardController

var _respawning := false
var _pillars: Array[CliffResonancePillar] = []


func _ready() -> void:
	super()
	respawn_position = player_spawn.global_position
	fade_rect.modulate.a = 0.0
	complete_label.visible = false
	_collect_pillars()
	receiver.receiver_activated.connect(_on_receiver_activated)
	if _is_cleared():
		for pillar: CliffResonancePillar in _pillars:
			pillar.set_stabilized(true, true)
		receiver.set_activated(true)
	_refresh_progress()


func request_respawn(body: Node2D, reason: String = "fall", damage: int = -1) -> void:
	if hazard_controller != null:
		hazard_controller.request_respawn(body, StringName(reason), damage)


func _collect_pillars() -> void:
	_pillars.clear()
	for node: Node in get_tree().get_nodes_in_group("cliff_resonance_pillars"):
		if not is_ancestor_of(node):
			continue
		if not (node is CliffResonancePillar):
			continue
		var pillar := node as CliffResonancePillar
		_pillars.append(pillar)
		pillar.stabilized.connect(_on_pillar_stabilized)
		for zone: Node in get_tree().get_nodes_in_group("cliff_avalanche_zones"):
			if is_ancestor_of(zone) and zone.has_method("on_resonance_burst"):
				pillar.resonance_burst.connect(Callable(zone, "on_resonance_burst"))


func _on_pillar_stabilized(_pillar_id: StringName) -> void:
	_refresh_progress()


func _refresh_progress() -> void:
	var stable_count := 0
	for pillar: CliffResonancePillar in _pillars:
		if pillar.is_stabilized():
			stable_count += 1
	receiver.set_progress(stable_count, _pillars.size())
	progress_label.text = "鸣晶校准  %d / %d" % [stable_count, _pillars.size()]


func _on_receiver_activated() -> void:
	var data := get_player_data()
	if data != null:
		data.tutorial_flags[CLEAR_FLAG] = true
	complete_label.visible = true
	complete_label.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(complete_label, "modulate:a", 1.0, 0.25)
	level_cleared.emit()

	if not completion_level_id.is_empty():
		var runtime := _get_day_runtime()
		if runtime != null and runtime.has_method("transition_to_level_with_blackout"):
			await get_tree().create_timer(0.8).timeout
			await runtime.transition_to_level_with_blackout(completion_level_id, completion_entry_id, true)


func _is_cleared() -> bool:
	var data := get_player_data()
	return data != null and bool(data.tutorial_flags.get(CLEAR_FLAG, false))


func _set_player_control(body: Node, enabled: bool) -> void:
	if body.has_method("set_control_enabled"):
		body.call("set_control_enabled", enabled)
		return
	if body.has_method("set_dialogue_locked"):
		body.call("set_dialogue_locked", not enabled)
	if body.has_method("set_potion_action_locked"):
		body.call("set_potion_action_locked", not enabled)


func _get_day_runtime() -> DayRuntime:
	var cursor: Node = get_parent()
	while cursor != null:
		if cursor is DayRuntime:
			return cursor as DayRuntime
		cursor = cursor.get_parent()
	return null
