extends Node2D

# WHITEBOX DEMO — no TileMap. All terrain visuals are Sprite2D textures, all physics is StaticBody2D.
# Replace placeholder_actor.tscn with the project's actual Sherry/Luca scenes during integration.

@export var sherry_scene: PackedScene
@export var luca_scene: PackedScene

const PLACEHOLDER := preload("res://scenes/placeholder_actor.tscn")
const WORLD_CORRUPTED := 0
const WORLD_ORIGINAL := 1

var current_world := WORLD_CORRUPTED
var active_actor: Node2D
var sherry: Node2D
var luca: Node2D
var anchor_activated := false
var seal_activated := false
var _switching := false

var corrupted_root: Node2D
var original_root: Node2D
var shared_root: Node2D
var corrupted_bridge: Node2D
var corruption_wall: Node2D
var final_gate: Node2D
var camera: Camera2D
var overlay: ColorRect
var info_label: Label
var objective_label: Label
var world_label: Label

func _ready() -> void:
    _build_world()
    _spawn_actors()
    _build_ui()
    _apply_world(WORLD_CORRUPTED, true)
    _refresh_objective()

func _process(delta: float) -> void:
    if is_instance_valid(camera) and is_instance_valid(active_actor):
        var target_x := clampf(active_actor.global_position.x, 640.0, 2960.0)
        camera.global_position = camera.global_position.lerp(Vector2(target_x, 360.0), 1.0 - pow(0.0008, delta))

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_Q or event.keycode == KEY_TAB:
            _request_switch()
            get_viewport().set_input_as_handled()
        elif event.keycode == KEY_R:
            get_tree().reload_current_scene()
            get_viewport().set_input_as_handled()

func _build_world() -> void:
    shared_root = Node2D.new()
    shared_root.name = "SharedWorld"
    add_child(shared_root)

    corrupted_root = Node2D.new()
    corrupted_root.name = "CorruptedWorld_Sherry"
    add_child(corrupted_root)

    original_root = Node2D.new()
    original_root.name = "OriginalWorld_Luca"
    add_child(original_root)

    # White background guide lines.
    _make_label(shared_root, Vector2(40, 60), "DUAL PROTAGONIST WHITEBOX / PURE SPRITE SCENE", 22)
    _make_label(shared_root, Vector2(40, 92), "Q / Tab: switch protagonist    ←→ or A/D: move    Space: jump    R: reset", 16)
    _make_label(shared_root, Vector2(40, 120), "Gray = shared world   Purple = Sherry/corrupted   Blue = Luca/original", 15)

    # Shared ground segments. The gap from x=800..1500 is the first world-dependent puzzle.
    _make_platform(shared_root, "res://assets/shared_ground.png", Vector2(400, 650), Vector2(800, 140), true, "SharedGround_A")
    _make_platform(shared_root, "res://assets/shared_ground.png", Vector2(1900, 650), Vector2(800, 140), true, "SharedGround_B")
    _make_platform(shared_root, "res://assets/shared_ground.png", Vector2(2950, 650), Vector2(1300, 140), true, "SharedGround_C")

    # Original world: Luca sees an intact bridge across the gap.
    _make_platform(original_root, "res://assets/original_bridge.png", Vector2(1150, 565), Vector2(700, 52), true, "OriginalBridge")
    _make_label(original_root, Vector2(930, 490), "Luca sees the intact world: cross this bridge", 17)

    # Corrupted world: bridge is absent until Luca activates the anchor.
    corruption_wall = _make_platform(corrupted_root, "res://assets/corruption_wall.png", Vector2(755, 500), Vector2(90, 300), true, "CorruptionWall")
    corrupted_bridge = _make_platform(corrupted_root, "res://assets/corrupted_bridge.png", Vector2(1150, 565), Vector2(700, 52), true, "StabilizedBridge")
    corrupted_bridge.visible = false
    _set_collision_tree(corrupted_bridge, false)
    _make_label(corrupted_root, Vector2(535, 330), "Sherry sees corruption: route blocked", 17)

    # Luca anchor on the far side.
    var anchor := _make_trigger(shared_root, Vector2(1700, 545), Vector2(120, 120), "LucaAnchor")
    var anchor_sprite := _make_sprite(shared_root, "res://assets/anchor.png", Vector2(1700, 540), Vector2(96, 96), "LucaAnchorVisual")
    anchor.body_entered.connect(_on_anchor_body_entered)
    _make_label(shared_root, Vector2(1550, 440), "① Luca anchor", 18)

    # Sherry seal farther right.
    var seal := _make_trigger(shared_root, Vector2(2250, 545), Vector2(120, 120), "SherrySeal")
    _make_sprite(shared_root, "res://assets/seal.png", Vector2(2250, 540), Vector2(96, 96), "SherrySealVisual")
    seal.body_entered.connect(_on_seal_body_entered)
    _make_label(shared_root, Vector2(2110, 440), "② Sherry seal", 18)

    # Final gate is shared state; Sherry seal opens it for both characters.
    final_gate = _make_platform(shared_root, "res://assets/gate.png", Vector2(2670, 500), Vector2(100, 300), true, "FinalGate")
    _make_label(shared_root, Vector2(2570, 320), "Final gate", 17)

    var goal := _make_trigger(shared_root, Vector2(3310, 530), Vector2(180, 220), "GoalArea")
    _make_sprite(shared_root, "res://assets/goal.png", Vector2(3310, 505), Vector2(130, 160), "GoalVisual")
    goal.body_entered.connect(_on_goal_body_entered)
    _make_label(shared_root, Vector2(3190, 360), "③ Exit", 18)

    # Camera is controlled by the currently active protagonist.
    camera = Camera2D.new()
    camera.name = "Camera2D"
    camera.enabled = true
    camera.position = Vector2(640, 360)
    add_child(camera)

func _spawn_actors() -> void:
    var sherry_packed := sherry_scene if sherry_scene != null else PLACEHOLDER
    var luca_packed := luca_scene if luca_scene != null else PLACEHOLDER

    sherry = sherry_packed.instantiate() as Node2D
    luca = luca_packed.instantiate() as Node2D
    sherry.name = "Sherry_SLOT_REPLACE_ME"
    luca.name = "Luca_SLOT_REPLACE_ME"
    sherry.position = Vector2(220, 570)
    luca.position = Vector2(300, 570)
    add_child(sherry)
    add_child(luca)

    # Standalone placeholders expose these fields. Real project scenes are adapted by Codex instead.
    if sherry_scene == null:
        sherry.set("actor_id", "sherry")
        sherry.set("display_name", "SHERRY SLOT")
    if luca_scene == null:
        luca.set("actor_id", "luca")
        luca.set("display_name", "LUCA SLOT")

    _set_actor_control(sherry, true)
    _set_actor_control(luca, false)
    active_actor = sherry

func _build_ui() -> void:
    var canvas := CanvasLayer.new()
    canvas.name = "UI"
    add_child(canvas)

    var panel := ColorRect.new()
    panel.position = Vector2(20, 18)
    panel.size = Vector2(540, 118)
    panel.color = Color(1, 1, 1, 0.92)
    canvas.add_child(panel)

    world_label = Label.new()
    world_label.position = Vector2(38, 30)
    world_label.add_theme_font_size_override("font_size", 20)
    world_label.add_theme_color_override("font_color", Color(0.10, 0.10, 0.10))
    canvas.add_child(world_label)

    objective_label = Label.new()
    objective_label.position = Vector2(38, 62)
    objective_label.size = Vector2(500, 50)
    objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    objective_label.add_theme_font_size_override("font_size", 16)
    objective_label.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
    canvas.add_child(objective_label)

    info_label = Label.new()
    info_label.position = Vector2(38, 112)
    info_label.add_theme_font_size_override("font_size", 14)
    info_label.add_theme_color_override("font_color", Color(0.30, 0.30, 0.30))
    info_label.text = "Q/Tab switch · Arrow/A-D move · Space jump · R reset"
    canvas.add_child(info_label)

    overlay = ColorRect.new()
    overlay.position = Vector2.ZERO
    overlay.size = Vector2(1280, 720)
    overlay.color = Color(0.24, 0.14, 0.30, 0.0)
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.z_index = 1000
    canvas.add_child(overlay)

func _request_switch() -> void:
    if _switching:
        return
    _switching = true
    _set_actor_control(active_actor, false)
    var target_world := WORLD_ORIGINAL if current_world == WORLD_CORRUPTED else WORLD_CORRUPTED
    var target_actor := luca if target_world == WORLD_ORIGINAL else sherry

    var tween := create_tween()
    tween.tween_property(overlay, "color", Color(0.24, 0.14, 0.30, 0.52), 0.12)
    tween.tween_callback(func():
        _apply_world(target_world)
        active_actor = target_actor
    )
    tween.tween_property(overlay, "color", Color(0.24, 0.14, 0.30, 0.0), 0.16)
    tween.tween_callback(func():
        _set_actor_control(active_actor, true)
        _switching = false
    )

func _apply_world(world: int, instant := false) -> void:
    current_world = world
    corrupted_root.visible = world == WORLD_CORRUPTED
    original_root.visible = world == WORLD_ORIGINAL
    _set_collision_tree(corrupted_root, world == WORLD_CORRUPTED)
    _set_collision_tree(original_root, world == WORLD_ORIGINAL)

    # Persistent puzzle state modifies the corrupted world after Luca's action.
    if anchor_activated:
        corruption_wall.visible = false
        _set_collision_tree(corruption_wall, false)
        corrupted_bridge.visible = world == WORLD_CORRUPTED
        _set_collision_tree(corrupted_bridge, world == WORLD_CORRUPTED)
    else:
        corruption_wall.visible = world == WORLD_CORRUPTED
        _set_collision_tree(corruption_wall, world == WORLD_CORRUPTED)
        corrupted_bridge.visible = false
        _set_collision_tree(corrupted_bridge, false)

    if seal_activated:
        final_gate.visible = false
        _set_collision_tree(final_gate, false)

    if is_instance_valid(world_label):
        world_label.text = "ACTIVE: SHERRY / CORRUPTED WORLD" if world == WORLD_CORRUPTED else "ACTIVE: LUCA / ORIGINAL WORLD"
    _refresh_objective()

func _on_anchor_body_entered(body: Node) -> void:
    if anchor_activated or current_world != WORLD_ORIGINAL or body != luca:
        return
    anchor_activated = true
    _refresh_objective()
    _flash_message("Luca stabilized the memory anchor. Sherry's blocked route now exists.")

func _on_seal_body_entered(body: Node) -> void:
    if seal_activated or not anchor_activated or current_world != WORLD_CORRUPTED or body != sherry:
        return
    seal_activated = true
    final_gate.visible = false
    _set_collision_tree(final_gate, false)
    _refresh_objective()
    _flash_message("Sherry activated the seal. The shared final gate is open.")

func _on_goal_body_entered(body: Node) -> void:
    if not seal_activated or body != active_actor:
        return
    objective_label.text = "DEMO COMPLETE — both world states and cross-character puzzle state were used. Press R to reset."
    _flash_message("Demo complete.")

func _refresh_objective() -> void:
    if not is_instance_valid(objective_label):
        return
    if not anchor_activated:
        objective_label.text = "Objective: switch to Luca, cross the intact bridge, and touch the Luca anchor."
    elif not seal_activated:
        objective_label.text = "Objective: switch back to Sherry. Her route is now stabilized; reach the Sherry seal."
    else:
        objective_label.text = "Objective: final gate is open. Reach the exit on the far right."

func _flash_message(text: String) -> void:
    if not is_instance_valid(info_label):
        return
    info_label.text = text
    var tween := create_tween()
    tween.tween_interval(2.2)
    tween.tween_callback(func():
        if is_instance_valid(info_label):
            info_label.text = "Q/Tab switch · Arrow/A-D move · Space jump · R reset"
    )

func _set_actor_control(actor: Node, enabled: bool) -> void:
    if actor == null:
        return
    if actor.has_method("set_control_enabled"):
        actor.call("set_control_enabled", enabled)
    else:
        # Integration fallback: Codex should adapt this to the project's own player controller API.
        actor.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED

func _make_platform(parent: Node2D, texture_path: String, center: Vector2, size: Vector2, collision: bool, object_name: String) -> Node2D:
    var root := Node2D.new()
    root.name = object_name
    root.position = center
    parent.add_child(root)
    var sprite := Sprite2D.new()
    sprite.texture = load(texture_path)
    sprite.scale = Vector2(size.x / sprite.texture.get_width(), size.y / sprite.texture.get_height())
    root.add_child(sprite)
    if collision:
        var body := StaticBody2D.new()
        body.collision_layer = 1
        body.collision_mask = 0
        root.add_child(body)
        var shape_node := CollisionShape2D.new()
        var shape := RectangleShape2D.new()
        shape.size = size
        shape_node.shape = shape
        body.add_child(shape_node)
    return root

func _make_sprite(parent: Node2D, texture_path: String, center: Vector2, size: Vector2, object_name: String) -> Sprite2D:
    var sprite := Sprite2D.new()
    sprite.name = object_name
    sprite.position = center
    sprite.texture = load(texture_path)
    sprite.scale = Vector2(size.x / sprite.texture.get_width(), size.y / sprite.texture.get_height())
    parent.add_child(sprite)
    return sprite

func _make_trigger(parent: Node2D, center: Vector2, size: Vector2, object_name: String) -> Area2D:
    var area := Area2D.new()
    area.name = object_name
    area.position = center
    area.collision_layer = 4
    area.collision_mask = 2
    parent.add_child(area)
    var collision := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = size
    collision.shape = shape
    area.add_child(collision)
    return area

func _make_label(parent: Node2D, pos: Vector2, text: String, size: int) -> Label:
    var label := Label.new()
    label.position = pos
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", Color(0.16, 0.16, 0.16, 1))
    label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 1))
    label.add_theme_constant_override("outline_size", 4)
    parent.add_child(label)
    return label

func _set_collision_tree(node: Node, enabled: bool) -> void:
    if node is CollisionShape2D or node is CollisionPolygon2D:
        node.set_deferred("disabled", not enabled)
    for child in node.get_children():
        _set_collision_tree(child, enabled)
