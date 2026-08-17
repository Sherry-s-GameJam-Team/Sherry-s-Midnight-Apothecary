extends Node2D

@export var interaction_action: StringName = &"interact"
@export var player_group: StringName = &"player"
@export var turn_speed := 1.3
@export var min_angle := deg_to_rad(-42.0)
@export var max_angle := deg_to_rad(18.0)
@export var max_range := 1700.0

var powered := false
var controlling := false
var player: Node = null
var firing := false

@onready var barrel: Node2D = $Barrel
@onready var muzzle: Marker2D = $Barrel/Muzzle
@onready var beam: Line2D = $Beam
@onready var prompt: Label = $InteractionArea/Prompt
@onready var area: Area2D = $InteractionArea
@onready var status: Label = $Status

func _ready() -> void:
    area.body_entered.connect(_on_enter)
    area.body_exited.connect(_on_exit)
    prompt.visible = false
    beam.visible = false
    _update_status()

func set_powered(value: bool) -> void:
    powered = value
    _update_status()

func _process(delta: float) -> void:
    if not controlling:
        return
    var axis := Input.get_axis("ui_left", "ui_right")
    barrel.rotation = clamp(barrel.rotation + axis * turn_speed * delta, min_angle, max_angle)

func _unhandled_input(event: InputEvent) -> void:
    if player == null:
        return
    if event.is_action_pressed(interaction_action):
        if not powered:
            status.text = "净化枪：泉路未供能"
            return
        if not controlling:
            controlling = true
            prompt.text = "← → 瞄准 / E 开火"
        elif not firing:
            fire()
        var vp := get_viewport()
        if vp != null:
            vp.set_input_as_handled()

func fire() -> void:
    firing = true
    var target := _find_eye()
    var end_pos: Vector2 = muzzle.global_position + Vector2.RIGHT.rotated(barrel.global_rotation) * max_range
    if target and target.has_method("try_purify"):
        if target.try_purify(muzzle.global_position, barrel.global_rotation, max_range):
            if target is Node2D:
                end_pos = (target as Node2D).global_position
    beam.clear_points()
    beam.add_point(to_local(muzzle.global_position))
    beam.add_point(to_local(end_pos))
    beam.visible = true
    beam.modulate.a = 1.0
    var tween := create_tween()
    tween.tween_property(beam, "modulate:a", 0.0, 0.20)
    await tween.finished
    beam.visible = false
    firing = false

func _on_enter(body: Node) -> void:
    if body.is_in_group(player_group) or body is CharacterBody2D:
        player = body
        prompt.visible = true
        prompt.text = "E 操作净化枪" if powered else "净化枪尚未供能"

func _on_exit(body: Node) -> void:
    if body == player:
        player = null
        controlling = false
        prompt.visible = false

func _update_status() -> void:
    if status:
        status.text = "净化枪：已供能" if powered else "净化枪：离线"
    if prompt and prompt.visible:
        prompt.text = "E 操作净化枪" if powered else "净化枪尚未供能"

func _find_eye() -> Node:
    var n: Node = get_parent()
    if n:
        return n.get_node_or_null("TideEye")
    return null
