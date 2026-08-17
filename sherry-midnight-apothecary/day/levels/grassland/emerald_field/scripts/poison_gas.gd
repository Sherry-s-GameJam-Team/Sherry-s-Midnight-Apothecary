extends Area2D

@export var max_exposure := 1.15
@export_range(0, 100, 1) var damage_per_exposure := 10
@export var pulse_speed := 1.6
@export var poison_color := Color(0.35, 0.92, 0.38, 0.30)
@onready var visual: Polygon2D = $GasVisual
var _exposure: Dictionary = {}
var _time := 0.0

func _ready() -> void:
	monitoring = true
	visual.color = poison_color

func _process(delta: float) -> void:
	_time += delta
	visual.color.a = poison_color.a + sin(_time * pulse_speed) * 0.055

func _physics_process(delta: float) -> void:
	var active_ids := {}
	for body in get_overlapping_bodies():
		if not body.is_in_group("player"):
			continue
		var id := body.get_instance_id()
		active_ids[id] = true
		_exposure[id] = float(_exposure.get(id, 0.0)) + delta
		if _exposure[id] >= max_exposure:
			_exposure[id] = 0.0
			var level := get_tree().get_first_node_in_group("emerald_level")
			if level and level.has_method("request_respawn"):
				level.request_respawn(body, "poison", damage_per_exposure)
	for id in _exposure.keys():
		if not active_ids.has(id):
			_exposure.erase(id)

func reset_hazard() -> void:
	_exposure.clear()
