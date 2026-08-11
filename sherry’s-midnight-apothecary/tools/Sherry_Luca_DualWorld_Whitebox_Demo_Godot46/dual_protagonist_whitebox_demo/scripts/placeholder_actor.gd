extends CharacterBody2D
class_name DualWorldPlaceholderActor

@export var actor_id: String = "actor"
@export var display_name: String = "ACTOR SLOT"
@export var speed: float = 320.0
@export var jump_velocity: float = -590.0

var control_enabled := false
var _gravity: float = 1500.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label
@onready var collider: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
    _gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)) * 1.55
    label.text = display_name + "
(placeholder)"
    set_control_enabled(control_enabled)

func set_control_enabled(enabled: bool) -> void:
    control_enabled = enabled
    velocity = Vector2.ZERO
    if is_instance_valid(collider):
        collider.set_deferred("disabled", not enabled)
    collision_layer = 2 if enabled else 0
    collision_mask = 1 if enabled else 0
    if is_instance_valid(sprite):
        sprite.modulate.a = 1.0 if enabled else 0.34
    if is_instance_valid(label):
        label.modulate.a = 1.0 if enabled else 0.45
    set_physics_process(enabled)

func _physics_process(delta: float) -> void:
    if not control_enabled:
        return

    var direction := Input.get_axis("ui_left", "ui_right")
    if Input.is_key_pressed(KEY_A):
        direction -= 1.0
    if Input.is_key_pressed(KEY_D):
        direction += 1.0
    direction = clampf(direction, -1.0, 1.0)

    if not is_on_floor():
        velocity.y += _gravity * delta

    if (Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_W)) and is_on_floor():
        velocity.y = jump_velocity

    if absf(direction) > 0.01:
        velocity.x = direction * speed
    else:
        velocity.x = move_toward(velocity.x, 0.0, speed * 8.0 * delta)

    move_and_slide()
