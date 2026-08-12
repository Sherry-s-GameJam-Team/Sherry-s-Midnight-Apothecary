class_name CrimsonAqueductRoot
extends Control

signal minigame_completed(result: Dictionary)
signal minigame_failed(result: Dictionary)
signal minigame_exited()

const DEFAULT_CONFIG := {
	"level_id": &"standard",
	"purifier_potions": 3,
	"sealant_potions": 2,
	"safe_pollution_threshold": 0.12,
	"minimum_clean_supply": 0.25,
	"stability_duration": 8.0,
}

var config: Dictionary = DEFAULT_CONFIG.duplicate(true)
var purifier_potions := 3
var sealant_potions := 2
var stability_time := 0.0
var sealed_cracks := 0
var _configured := false
var _finished := false

@onready var pipe_network: PipeNetwork = %PipeNetwork
@onready var mouse_controller: FPMouseController = %FPMouseController
@onready var reservoir_display: ReservoirDisplay = %ReservoirDisplay
@onready var hud: UIHud = %UIHud


func _ready() -> void:
	_connect_children()
	_apply_config(config)


func setup(new_config: Dictionary) -> void:
	config = _sanitize_config(new_config)
	_configured = true
	if is_node_ready():
		_apply_config(config)


func _process(delta: float) -> void:
	if _finished or not is_node_ready():
		return
	pipe_network.advance(delta)
	var snapshot := pipe_network.get_snapshot()
	var pollution: float = snapshot["reservoir_pollution"]
	var supply: float = snapshot["clean_supply"]
	var safe := pollution <= float(config["safe_pollution_threshold"]) and supply >= float(config["minimum_clean_supply"])
	stability_time = minf(stability_time + delta, float(config["stability_duration"])) if safe else 0.0
	var stability_ratio := stability_time / maxf(float(config["stability_duration"]), 0.1)
	reservoir_display.update_display(pollution, supply, float(snapshot["pressure"]), stability_ratio)
	_sync_purifier_visuals()
	hud.update_status(config["level_id"], purifier_potions, sealant_potions, mouse_controller.current_mode)
	if stability_time >= float(config["stability_duration"]):
		_finish_completed()


func _sanitize_config(new_config: Dictionary) -> Dictionary:
	var result := DEFAULT_CONFIG.duplicate(true)
	for key: String in DEFAULT_CONFIG:
		if new_config.has(key):
			result[key] = new_config[key]
	var requested_id := StringName(str(result["level_id"]))
	result["level_id"] = requested_id if PipeNetwork.LEVEL_IDS.has(requested_id) else &"standard"
	result["purifier_potions"] = maxi(int(result["purifier_potions"]), 0)
	result["sealant_potions"] = maxi(int(result["sealant_potions"]), 0)
	result["safe_pollution_threshold"] = clampf(float(result["safe_pollution_threshold"]), 0.0, 1.0)
	result["minimum_clean_supply"] = clampf(float(result["minimum_clean_supply"]), 0.0, 1.0)
	result["stability_duration"] = maxf(float(result["stability_duration"]), 0.1)
	return result


func _apply_config(value: Dictionary) -> void:
	config = _sanitize_config(value)
	purifier_potions = int(config["purifier_potions"])
	sealant_potions = int(config["sealant_potions"])
	stability_time = 0.0
	sealed_cracks = 0
	_finished = false
	pipe_network.configure(config["level_id"])
	mouse_controller.enabled = true
	mouse_controller.cancel()
	hud.set_interaction_enabled(true)
	_sync_initial_interactables()
	hud.update_status(config["level_id"], purifier_potions, sealant_potions, mouse_controller.current_mode)


func _connect_children() -> void:
	hud.potion_mode_requested.connect(mouse_controller.set_mode)
	hud.exit_requested.connect(_on_exit_requested)
	mouse_controller.mode_changed.connect(_on_mode_changed)
	mouse_controller.interaction_cancelled.connect(_cancel_drags)
	for child in %Interactables.get_children():
		if child is ValveInteractable:
			child.state_changed.connect(pipe_network.set_valve_state)
		elif child is DiverterInteractable:
			child.direction_changed.connect(pipe_network.set_diverter_direction)
		elif child is PurifierInteractable:
			child.use_requested.connect(_on_purifier_requested)
		elif child is CrackInteractable:
			child.seal_requested.connect(_on_seal_requested)


func _sync_initial_interactables() -> void:
	for child in %Interactables.get_children():
		child.visible = _is_interactable_used(child)
		child.enabled = child.visible
		if child is ValveInteractable:
			pipe_network.set_valve_state(child.valve_id, child.get_openness())
		elif child is DiverterInteractable:
			pipe_network.set_diverter_direction(child.diverter_id, child.direction)
		elif child is CrackInteractable:
			child.set_sealed(false)


func _is_interactable_used(child: Node) -> bool:
	if child is CrackInteractable:
		return pipe_network.cracks.has(child.crack_id)
	return true


func _on_mode_changed(_mode: StringName) -> void:
	hud.update_status(config["level_id"], purifier_potions, sealant_potions, mouse_controller.current_mode)


func _on_purifier_requested(purifier_id: StringName) -> void:
	if mouse_controller.current_mode != FPMouseController.MODE_PURIFIER:
		hud.show_feedback("先在左侧选择净化药剂", true)
		return
	if purifier_potions <= 0:
		hud.show_feedback("净化药剂已经用尽", true)
		return
	if pipe_network.activate_purifier(purifier_id):
		purifier_potions -= 1
		var purifier := _find_interactable(purifier_id) as PurifierInteractable
		if purifier != null:
			purifier.set_active(true)
		hud.show_feedback("净化符文已经点亮")
		mouse_controller.cancel()


func _on_seal_requested(crack_id: StringName) -> void:
	if mouse_controller.current_mode != FPMouseController.MODE_SEALANT:
		hud.show_feedback("先在左侧选择封堵药剂", true)
		return
	if sealant_potions <= 0:
		hud.show_feedback("封堵药剂已经用尽", true)
		return
	if pipe_network.seal_crack(crack_id):
		sealant_potions -= 1
		sealed_cracks += 1
		var crack := _find_interactable(crack_id) as CrackInteractable
		if crack != null:
			crack.set_sealed(true)
		hud.show_feedback("裂缝已经封闭")
		mouse_controller.cancel()


func _find_interactable(id: StringName) -> Node:
	for child in %Interactables.get_children():
		if child is PurifierInteractable and child.purifier_id == id:
			return child
		if child is CrackInteractable and child.crack_id == id:
			return child
	return null


func _sync_purifier_visuals() -> void:
	for child in %Interactables.get_children():
		if child is PurifierInteractable:
			var data: Dictionary = pipe_network.purifiers.get(child.purifier_id, {})
			child.set_active(float(data.get("remaining", 0.0)) > 0.0)


func _cancel_drags() -> void:
	for child in %Interactables.get_children():
		if child is DiverterInteractable:
			child.cancel_drag()


func _on_exit_requested() -> void:
	if not _finished:
		minigame_exited.emit()


func _finish_completed() -> void:
	if _finished:
		return
	_finished = true
	pipe_network.running = false
	mouse_controller.enabled = false
	hud.set_interaction_enabled(false)
	for child in %Interactables.get_children():
		child.enabled = false
	minigame_completed.emit(_build_result())


func _build_result() -> Dictionary:
	var snapshot := pipe_network.get_snapshot()
	var score := maxi(0, int(1000.0 * (1.0 - float(snapshot["reservoir_pollution"])) + (purifier_potions + sealant_potions) * 75.0))
	return {
		"level_id": config["level_id"],
		"reason": &"water_secured",
		"reservoir_pollution": snapshot["reservoir_pollution"],
		"clean_supply": snapshot["clean_supply"],
		"purifier_potions": purifier_potions,
		"sealant_potions": sealant_potions,
		"sealed_cracks": sealed_cracks,
		"score": score,
	}
