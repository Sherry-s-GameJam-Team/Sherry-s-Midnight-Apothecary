class_name ControllerBase
extends Node2D

## 控制组件基类：维护激活/未激活两种状态，并在编辑器中与受控节点配对。

signal activated
signal deactivated
signal state_changed(is_active: bool)

@export var is_active := false:
	set(value):
		if is_active == value:
			return
		is_active = value
		if is_node_ready():
			_update_state()

## 在编辑器中拖放任一受控节点到此数组即可完成配对。
## 受控节点需实现 set_controlled_active(active: bool)，或继承 ControlledBase。
@export var controlled_nodes: Array[NodePath]

@export var active_color := Color(0.2, 0.76, 0.42, 1.0)
@export var inactive_color := Color(0.76, 0.22, 0.22, 1.0)


func _ready() -> void:
	_update_visual()
	_connect_controlled_nodes()
	if is_active:
		_notify_controlled_nodes(true)


func set_active(value: bool) -> void:
	is_active = value


func toggle() -> void:
	is_active = not is_active


func _update_state() -> void:
	_update_visual()
	if is_active:
		activated.emit()
	else:
		deactivated.emit()
	state_changed.emit(is_active)
	_notify_controlled_nodes(is_active)


func _connect_controlled_nodes() -> void:
	for path: NodePath in controlled_nodes:
		var node := get_node_or_null(path)
		if node == null:
			continue
		if node.has_method("set_controlled_active"):
			activated.connect(node.set_controlled_active.bind(true))
			deactivated.connect(node.set_controlled_active.bind(false))
		elif node.has_method("on_controller_activated"):
			activated.connect(node.on_controller_activated)
			deactivated.connect(node.on_controller_deactivated)


func _notify_controlled_nodes(active: bool) -> void:
	for path: NodePath in controlled_nodes:
		var node := get_node_or_null(path)
		if node == null:
			continue
		if node.has_method("set_controlled_active"):
			node.set_controlled_active(active)
		elif node.has_method("on_controller_activated"):
			if active:
				node.on_controller_activated()
			else:
				node.on_controller_deactivated()


func _update_visual() -> void:
	pass
