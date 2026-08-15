class_name ForestBossInterface
extends Node

signal boss_started
signal boss_purified

@export var corrupted_sprite_path: NodePath
@export var normal_sprite_path: NodePath
@export var forest_path: NodePath
var started := false
var purified := false

func begin_boss() -> void:
	if started or purified:
		return
	started = true
	boss_started.emit()

func purify_boss() -> void:
	if purified:
		return
	purified = true
	var corrupted := get_node_or_null(corrupted_sprite_path) as CanvasItem
	var normal := get_node_or_null(normal_sprite_path) as CanvasItem
	if corrupted != null:
		corrupted.visible = false
	if normal != null:
		normal.visible = true
	var forest := get_node_or_null(forest_path)
	if forest != null and forest.has_method("complete_restoration"):
		forest.call("complete_restoration")
	boss_purified.emit()
