class_name MarketFountainEventAppearance
extends Sprite2D

## Presentation-only bridge from the persistent day-one story event to Town's
## fountain artwork. Keep the Inspector switch available for content testing
## or for temporarily disabling the reveal without changing saved event data.

@export var blood_fountain_enabled := true
@export_range(1, 30, 1) var blood_fountain_day := 1
@export var blood_fountain_event_flag: StringName = &"lumen_street_blood_fountain_active"
@export var blood_fountain_scene: PackedScene

@onready var fountain_sprite: AnimatedSprite2D = $FountainSprite


func _ready() -> void:

	refresh_from_story_state()


func refresh_from_story_state() -> void:
	if fountain_sprite == null or not should_use_blood_fountain(_current_day(), _player_data()):
		return
	_apply_blood_fountain_frames()


func should_use_blood_fountain(current_day: int, player_data: PlayerData) -> bool:
	return blood_fountain_enabled and current_day == blood_fountain_day


func _apply_blood_fountain_frames() -> void:
	if blood_fountain_scene == null:
		push_warning("Town Fountain is configured for the blood-fountain event but has no frame scene.")
		return
	var blood_sprite := blood_fountain_scene.instantiate() as AnimatedSprite2D
	if blood_sprite == null:
		push_warning("Town Fountain blood-fountain scene must have an AnimatedSprite2D root.")
		return
	fountain_sprite.sprite_frames = blood_sprite.sprite_frames
	fountain_sprite.animation = blood_sprite.animation
	fountain_sprite.autoplay = blood_sprite.autoplay
	fountain_sprite.offset = blood_sprite.offset
	blood_sprite.free()
	fountain_sprite.play()


func _current_day() -> int:
	var current: Node = get_parent()
	while current != null:
		if current is DayRuntime:
			return current.day
		current = current.get_parent()
	return -1


func _player_data() -> PlayerData:
	var current: Node = get_parent()
	while current != null:
		if current.has_method("get_player_data"):
			return current.call("get_player_data") as PlayerData
		current = current.get_parent()
	return null
