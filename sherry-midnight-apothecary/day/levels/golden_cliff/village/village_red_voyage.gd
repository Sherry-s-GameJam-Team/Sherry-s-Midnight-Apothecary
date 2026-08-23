class_name VillageRedVoyage
extends Node2D

const VOYAGE_SECONDS := 5.0

@onready var far_scenery: Node2D = $FarScenery
@onready var mid_scenery: Node2D = $MidScenery
@onready var fade: ColorRect = $FadeLayer/Fade


func _ready() -> void:
	fade.color.a = 1.0
	play_voyage()


func play_voyage() -> void:
	var fade_in := create_tween()
	fade_in.tween_property(fade, "color:a", 0.0, 0.45)
	var scenery := create_tween().set_parallel(true)
	scenery.tween_property(far_scenery, "position:x", far_scenery.position.x - 780.0, VOYAGE_SECONDS).set_trans(Tween.TRANS_LINEAR)
	scenery.tween_property(mid_scenery, "position:x", mid_scenery.position.x - 1080.0, VOYAGE_SECONDS).set_trans(Tween.TRANS_LINEAR)
	await get_tree().create_timer(VOYAGE_SECONDS).timeout
	var fade_out := create_tween()
	fade_out.tween_property(fade, "color:a", 1.0, 0.45)
	await fade_out.finished
	var runtime := _find_day_runtime()
	if runtime != null:
		runtime.transition_to_level_with_blackout("crimson_vale", &"from_village", true)


func _find_day_runtime() -> DayRuntime:
	var current: Node = self
	while current != null:
		if current is DayRuntime:
			return current
		current = current.get_parent()
	return null
