extends Node2D

signal minigame_completed

@export var target_combo: int = 20
@export var anchor_lifetime: float = 1.05
@export var anchor_open_ratio: float = 0.28
@export var anchor_radius: float = 52.0
@export var respawn_delay: float = 0.16

var combo: int = 0
var total_hits: int = 0
var total_misses: int = 0
var finished: bool = false
var spawn_wait: float = 0.35
var active_anchor: MiasmaClickAnchor = null
var last_point_index: int = -1
var rng := RandomNumberGenerator.new()

@onready var anchor_layer: Node2D = $World/AnchorLayer
@onready var anchor_points: Node2D = $World/AnchorPoints
@onready var camera: Camera2D = $Camera2D
@onready var combo_label: Label = $UI/HUD/ComboLabel
@onready var progress_label: Label = $UI/HUD/ProgressLabel
@onready var feedback_label: Label = $UI/HUD/FeedbackLabel
@onready var hint_label: Label = $UI/HUD/HintLabel
@onready var success_panel: Panel = $UI/SuccessPanel
@onready var fog_nodes: Node2D = $World/Fog

func _ready() -> void:
	rng.randomize()
	# This scene is also instanced over Emerald Field. Explicitly take the
	# viewport so the purifier background and anchors replace the level view.
	camera.make_current()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	success_panel.visible = false
	feedback_label.text = ""
	hint_label.text = "在外圈收缩至锚点附近时单击 · 连击20次完成净化 · 漏点或点空会重置连击"
	_update_ui()

func _process(delta: float) -> void:
	if finished:
		return

	if active_anchor != null:
		if active_anchor.advance(delta):
			_register_miss("MISS · 超时")
	else:
		spawn_wait -= delta
		if spawn_wait <= 0.0:
			_spawn_anchor()

func _unhandled_input(event: InputEvent) -> void:
	if finished:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_click()

func _handle_click() -> void:
	if active_anchor == null:
		_register_miss("MISS · 点空")
		return

	var mouse_world := get_global_mouse_position()
	if not active_anchor.is_point_inside(mouse_world):
		_register_miss("MISS · 点空")
		return

	if not active_anchor.can_hit():
		_register_miss("MISS · 过早")
		return

	var p := active_anchor.progress()
	var quality := "GOOD"
	if p >= 0.72:
		quality = "PERFECT"
	elif p >= 0.48:
		quality = "GREAT"

	active_anchor.resolve()
	active_anchor = null
	combo += 1
	total_hits += 1
	feedback_label.text = "%s  +1" % quality
	spawn_wait = respawn_delay
	_update_ui()

	if combo >= target_combo:
		_complete_minigame()

func _register_miss(reason: String) -> void:
	if active_anchor != null:
		active_anchor.resolve()
		active_anchor = null
	combo = 0
	total_misses += 1
	feedback_label.text = reason
	spawn_wait = maxf(respawn_delay, 0.28)
	_update_ui()

func _spawn_anchor() -> void:
	var points := anchor_points.get_children()
	if points.is_empty():
		return

	var idx := rng.randi_range(0, points.size() - 1)
	if points.size() > 1:
		while idx == last_point_index:
			idx = rng.randi_range(0, points.size() - 1)
	last_point_index = idx

	var marker := points[idx] as Marker2D
	if marker == null:
		return

	var anchor := MiasmaClickAnchor.new()
	anchor.hit_radius = anchor_radius
	anchor.lifetime = anchor_lifetime
	anchor.open_ratio = anchor_open_ratio
	anchor.sequence_number = combo + 1
	anchor_layer.add_child(anchor)
	anchor.global_position = marker.global_position
	active_anchor = anchor

func _complete_minigame() -> void:
	finished = true
	if active_anchor != null:
		active_anchor.resolve()
		active_anchor = null
	feedback_label.text = "20 COMBO"
	combo_label.text = "净化完成"
	progress_label.text = "%d / %d" % [target_combo, target_combo]
	hint_label.text = "翡翠原的瘴气正在消散"
	success_panel.visible = true
	for child in fog_nodes.get_children():
		if child is GPUParticles2D:
			child.emitting = false
	minigame_completed.emit()

func _update_ui() -> void:
	combo_label.text = "COMBO  %02d" % combo
	progress_label.text = "%d / %d" % [combo, target_combo]
