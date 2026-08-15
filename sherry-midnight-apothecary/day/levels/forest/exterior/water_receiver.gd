class_name ForestWaterReceiver
extends Area2D

signal water_received(source: Node)

@export var accepts_water := true
var supplied := false

func receive_water(source: Node) -> void:
	if not accepts_water or supplied:
		return
	supplied = true
	water_received.emit(source)
