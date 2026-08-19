class_name VespervaleRunnerLevel
extends DayLevelEnvironment

## Vespervale 2-Minute Dual-Character Parkour Gauntlet (梦疗院·疾驰回廊).
## Auto-runner parkour level with Sherry on lower track (Space key to jump)
## and Luca on upper track (W key to jump).
## Runs continuously for 2 minutes (120s) until reaching the finish sanctuary.

signal objective_updated(text: String, hint: String)
signal level_completed

@export var is_runner_cleared: bool = false

@onready var runner_controller: RunnerController = get_node_or_null("RunnerController")
@onready var runner_hud: RunnerHUD = get_node_or_null("RunnerHUD")


func _ready() -> void:
	super._ready()
	add_to_group("vespervale_runner")

	if runner_controller != null:
		runner_controller.exit_portal_unlocked.connect(_on_exit_portal_unlocked)

	objective_updated.emit(
		"梦疗院·疾驰回廊 (2分钟跑酷)",
		"[W 键] 控制下层雪莉跳跃，[空格 Space] 控制上层卢卡跳跃！坚持疾驰至终点。"
	)


func _on_exit_portal_unlocked() -> void:
	objective_updated.emit("已抵达终点！", "按 [E] 离开梦境疾驰。")


func on_runner_completed() -> void:
	if is_runner_cleared:
		return
	is_runner_cleared = true
	level_completed.emit()

	var data := get_player_data()
	if data != null and data.tutorial_flags != null:
		data.tutorial_flags["vespervale_runner_cleared"] = true

	var tree := get_tree()
	if tree != null:
		# Transition back to Vespervale Garden
		var garden_scene := "res://day/levels/Vespervale/garden.tscn"
		tree.change_scene_to_file(garden_scene)
