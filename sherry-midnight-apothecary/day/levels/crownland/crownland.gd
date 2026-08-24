class_name CrownlandLevel
extends DayLevelEnvironment

## Presentation and state contract for the Crownland daytime level.
##
## The level keeps both normal and corrupted artwork in the scene so story
## systems can switch the environment without replacing the active scene.

@onready var normal_sky: CanvasItem = $Background/FS/NormalSky
@onready var corrupted_sky: CanvasItem = $Background/FS/CorruptedSky
@onready var normal_city: CanvasItem = $Background/CS/City
@onready var corrupted_garden: CanvasItem = $Background/CS/CorruptedGarden
@onready var day_six_escort: DaySixCrownlandEscort = get_node_or_null("DaySixCrownlandEscort") as DaySixCrownlandEscort


func _ready() -> void:
	super._ready()
	_update_visual_state()


func set_corrupted(corrupted: bool) -> void:
	super.set_corrupted(corrupted)
	_update_visual_state()


func on_level_entered(entry_id: StringName) -> void:
	if day_six_escort != null:
		day_six_escort.begin_for_entry(entry_id)


func _update_visual_state() -> void:
	var corrupted := is_corrupted()
	var normal_sky_node := normal_sky if normal_sky != null else get_node_or_null("Background/FS/NormalSky") as CanvasItem
	var corrupted_sky_node := corrupted_sky if corrupted_sky != null else get_node_or_null("Background/FS/CorruptedSky") as CanvasItem
	var normal_city_node := normal_city if normal_city != null else get_node_or_null("Background/CS/City") as CanvasItem
	var corrupted_garden_node := corrupted_garden if corrupted_garden != null else get_node_or_null("Background/CS/CorruptedGarden") as CanvasItem
	if normal_sky_node != null:
		normal_sky_node.visible = not corrupted
	if corrupted_sky_node != null:
		corrupted_sky_node.visible = corrupted
	if normal_city_node != null:
		normal_city_node.visible = not corrupted
	if corrupted_garden_node != null:
		corrupted_garden_node.visible = corrupted
