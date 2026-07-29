class_name AppRoot
extends Node

const GameSessionScript := preload("res://core/state/game_session.gd")
const SceneFlowScript := preload("res://core/scene_flow/scene_flow.gd")
const DataRegistryScript := preload("res://core/data_registry/data_registry.gd")

@export var static_definitions: Array[Resource] = []
@onready var current_mode_slot: Node = $CurrentModeSlot

var session: GameSession
var game_flow: GameFlow
var scene_flow: SceneFlow
var data_registry: DataRegistry


func _ready() -> void:
	data_registry = DataRegistryScript.new()
	data_registry.register_all(static_definitions)
	scene_flow = SceneFlowScript.new()
	scene_flow.name = "SceneFlow"
	add_child(scene_flow)
	scene_flow.configure(current_mode_slot)

	session = GameSessionScript.new()
	game_flow = $GameFlow as GameFlow
	game_flow.configure(session, scene_flow)


func start_new_game() -> void:
	session.reset_to_new_game()
	game_flow.start_new_game()


func load_game(save_data: Dictionary) -> void:
	session = GameSessionScript.from_save_data(save_data)
	game_flow.configure(session, scene_flow)
	game_flow.resume_from_session()


func get_save_data() -> Dictionary:
	return session.to_save_data()
