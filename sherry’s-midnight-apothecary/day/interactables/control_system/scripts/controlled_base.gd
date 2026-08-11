class_name ControlledBase
extends Node2D

## 受控组件基类：接收来自 ControllerBase 的状态并驱动具体行为。

signal state_changed(is_active: bool)
signal activated
signal deactivated

## 反转控制信号：控制器激活时，受控组件表现为未激活。
@export var invert := false

## 单次触发：状态首次有效变化后忽略后续变化。
@export var one_shot := false

@export var active_color := Color(0.2, 0.76, 0.42, 1.0)
@export var inactive_color := Color(0.5, 0.5, 0.55, 1.0)

var _last_effective_state := false


func _ready() -> void:
	_update_visual(_last_effective_state)


func set_active(active: bool) -> void:
	set_controlled_active(active)


func set_controlled_active(active: bool) -> void:
	var effective := active != invert
	if one_shot and _last_effective_state == effective:
		return
	_last_effective_state = effective
	state_changed.emit(effective)
	if effective:
		activated.emit()
	else:
		deactivated.emit()
	_on_state_changed(effective)
	_update_visual(effective)


func on_controller_activated() -> void:
	set_controlled_active(true)


func on_controller_deactivated() -> void:
	set_controlled_active(false)


func _on_state_changed(_active: bool) -> void:
	pass


func _update_visual(_active: bool) -> void:
	pass
