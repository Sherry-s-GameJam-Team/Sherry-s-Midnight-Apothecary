class_name ForestLotusPlatform
extends AnimatableBody2D

signal activated_changed(active: bool)

@export var sink_distance := 10.0
@export var sink_time := 0.12
@export var rebound_time := 0.16

var activated := false
var _base_position := Vector2.ZERO

@onready var trigger: Area2D = $StepTrigger
@onready var closed_visual: CanvasItem = $ClosedVisual
@onready var water_stream: CanvasItem = $WaterStream
@onready var water_area: Area2D = $WaterStream/WaterStreamArea
@onready var water_collision: CollisionShape2D = $WaterStream/WaterStreamArea/CollisionShape2D

func _ready() -> void:
	_base_position = position
	trigger.body_entered.connect(_on_body_entered)
	water_area.area_entered.connect(_on_water_area_entered)
	closed_visual.visible = not activated
	water_stream.visible = activated
	water_collision.disabled = not activated

func _on_body_entered(body: Node) -> void:
	if activated or not _is_character(body):
		return
	activate()


## Any direct potion impact activates the lotus. PotionProjectile discovers this
## method on the collision body, so no potion-specific collision setup is needed.
func receive_potion_hit(_hit: Dictionary) -> void:
	activate()

func activate() -> void:
	if activated:
		return
	activated = true
	closed_visual.visible = false
	water_stream.visible = true
	water_collision.set_deferred("disabled", false)
	activated_changed.emit(true)
	var tween := create_tween()
	tween.tween_property(self, "position:y", _base_position.y + sink_distance, sink_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", _base_position.y, rebound_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().physics_frame
	for area: Area2D in water_area.get_overlapping_areas():
		_deliver_water(area)

func _on_water_area_entered(area: Area2D) -> void:
	if activated:
		_deliver_water(area)

func _deliver_water(area: Area2D) -> void:
	if area.has_method("receive_water"):
		area.call("receive_water", self)

func _is_character(body: Node) -> bool:
	return body.is_in_group("player") or body.is_in_group("forest_character") or body.name == "Player" or body.name == "Luca"
