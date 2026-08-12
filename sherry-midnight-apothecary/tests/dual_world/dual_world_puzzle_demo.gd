extends DayLevelEnvironment

const ANCHOR_KEY := &"luca_anchor_01"
const SEAL_KEY := &"sherry_seal_01"

@onready var world_manager: DualWorldManager = $Systems/DualWorldManager
@onready var protagonists: DualProtagonistController = $Systems/DualProtagonistController
@onready var world_state: DualWorldState = $Systems/DualWorldState
@onready var sherry: CharacterBody2D = $Actors/Sherry
@onready var luca: CharacterBody2D = $Actors/Luca
@onready var anchor: DualWorldPressurePlateController = $SharedWorld/SharedInteractables/LucaAnchor
@onready var seal: DualWorldPressurePlateController = $SharedWorld/SharedInteractables/SherrySeal
@onready var goal: Area2D = $SharedWorld/SharedInteractables/LevelGoal
@onready var gate: ControlledDoor = $SharedWorld/SharedCollision/FinalGate
@onready var wall: ControlledDoor = $CorruptedWorld/CorruptionWall
@onready var bridge: ControlledBridge = $CorruptedWorld/StabilizedBridge
@onready var status_label: Label = $UI/Panel/Status


func _ready() -> void:
	super()
	anchor.activated.connect(_on_anchor_activated)
	seal.activated.connect(_on_seal_activated)
	goal.body_entered.connect(_on_goal_body_entered)
	world_state.state_changed.connect(_on_state_changed)
	world_manager.world_changed.connect(_on_world_changed)
	protagonists.active_actor_changed.connect(_on_actor_changed)
	protagonists.actor_change_blocked.connect(_on_actor_change_blocked)
	_refresh_puzzle()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().reload_current_scene()


func _on_anchor_activated() -> void:
	world_state.set_flag(ANCHOR_KEY)


func _on_seal_activated() -> void:
	world_state.set_flag(SEAL_KEY)


func _on_goal_body_entered(body: Node) -> void:
	if body == protagonists.get_active_actor_node() and world_state.is_flag_set(SEAL_KEY):
		status_label.text = "COMPLETE: both protagonists and both worlds were used. Esc resets."


func _on_state_changed(_key: StringName, _value: Variant) -> void:
	_refresh_puzzle()


func _on_world_changed(_world_state: DualWorldManager.WorldState) -> void:
	_refresh_status()


func _on_actor_changed(_actor: DualProtagonistController.Actor) -> void:
	_refresh_status()


func _on_actor_change_blocked(_actor: DualProtagonistController.Actor, reason: String) -> void:
	status_label.text = reason


func _refresh_puzzle() -> void:
	var anchor_active := world_state.is_flag_set(ANCHOR_KEY)
	var seal_active := world_state.is_flag_set(SEAL_KEY)
	bridge.set_active(anchor_active)
	wall.set_active(anchor_active)
	gate.set_active(seal_active)
	_refresh_status()


func _refresh_status() -> void:
	if world_state.is_flag_set(SEAL_KEY):
		status_label.text = "Gate open. Reach LevelEnd. Q switches protagonist; Esc resets."
	elif world_state.is_flag_set(ANCHOR_KEY):
		status_label.text = "Anchor stable. Switch to Sherry and touch the violet seal."
	elif protagonists.active_actor == DualProtagonistController.Actor.SHERRY:
		status_label.text = "Sherry / CORRUPTED: route broken. Press Q to switch to Luca."
	else:
		status_label.text = "Luca / ORIGINAL: cross the blue bridge and touch the anchor."
