class_name BedroomIntroBridge
extends Node

signal completed
signal failed(message: String)
signal finished(success: bool)

@export_range(0.0, 2.0, 0.05) var camera_settle_delay := 0.1

var is_finished := false
var succeeded := false


func run(runtime: Node) -> void:
	is_finished = false
	succeeded = false
	var day_runtime := runtime as DayRuntime
	if day_runtime == null or day_runtime.current_level_instance == null:
		_finish_failure("Bedroom intro requires an active DayRuntime level.")
		return
	await get_tree().create_timer(camera_settle_delay).timeout
	var executor := _find_executor(day_runtime.current_level_instance)
	if executor == null:
		_finish_failure("Bedroom has no AnimationPresentationExecutor.")
		return
	# Entering through the main menu is a new opening shot even when this day's
	# tutorial flag was already saved. Direct in-world visits still respect the
	# executor's one-shot-per-day behavior.
	var did_start := executor.start(true)
	if not did_start and not executor.is_completed():
		_finish_failure("Bedroom wake-up presentation could not start.")
		return
	if not executor.is_completed():
		await executor.completed
	is_finished = true
	succeeded = true
	completed.emit()
	finished.emit(true)


func _finish_failure(message: String) -> void:
	is_finished = true
	succeeded = false
	failed.emit(message)
	finished.emit(false)


func _find_executor(level: Node) -> AnimationPresentationExecutor:
	for child: Node in level.find_children("*", "AnimationPresentationExecutor", true, false):
		return child as AnimationPresentationExecutor
	return null
