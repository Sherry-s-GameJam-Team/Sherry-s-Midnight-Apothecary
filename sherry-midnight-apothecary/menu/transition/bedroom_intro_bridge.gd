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
	var day_six_opening := day_runtime.current_level_instance.get_node_or_null("DaySixOpening") as DaySixOpening
	if day_six_opening != null and day_six_opening.is_opening_active():
		day_six_opening.start()
		await day_six_opening.opening_completed
		_finish_success()
		return
	var day_two_opening := day_runtime.current_level_instance.get_node_or_null("DayTwoOpening") as DayTwoOpening
	if day_two_opening != null and day_two_opening.is_opening_active():
		day_two_opening.start()
		await day_two_opening.opening_completed
		_finish_success()
		return
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
	_finish_success()


func _finish_success() -> void:
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
