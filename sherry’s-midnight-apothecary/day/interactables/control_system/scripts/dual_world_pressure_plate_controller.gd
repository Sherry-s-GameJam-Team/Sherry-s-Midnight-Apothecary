class_name DualWorldPressurePlateController
extends PressurePlateController

## 双世界专用压力板：只有指定主角在指定世界中踩上去时才会激活。

@export var required_actor := DualProtagonistController.Actor.LUCA
@export var required_world := DualWorldManager.WorldState.ORIGINAL
@export var protagonists_path: NodePath = "../../Systems/DualProtagonistController"
@export var world_manager_path: NodePath = "../../Systems/DualWorldManager"

@onready var _protagonists: DualProtagonistController = get_node(protagonists_path)
@onready var _world_manager: DualWorldManager = get_node(world_manager_path)


func _is_valid_body(body: Node2D) -> bool:
	if not super(body):
		return false
	
	var actor_node := _protagonists.get_active_actor_node()
	if actor_node == null or body != actor_node:
		return false
	
	if _protagonists.active_actor != required_actor:
		return false
	
	if _world_manager.current_world != required_world:
		return false
	
	return true
