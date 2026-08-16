extends Area2D

@export_range(0, 100, 1) var damage: int = 15
@export var source_id: StringName = &"golden_cliff_fall"

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
    if body.name != "Player":
        return
    var runtime := _find_day_runtime()
    if runtime != null:
        if bool(runtime.apply_player_damage(damage, source_id)):
            return
    var respawn := _find_respawn_position(body.global_position)
    body.global_position = respawn
    if body is CharacterBody2D:
        (body as CharacterBody2D).velocity = Vector2.ZERO

func _find_day_runtime() -> Node:
    # Duck-typed: avoids compile-time preload cycle via DayRuntime (see
    # day_runtime.gd LEVELS chain and emerald_field_level.gd note).
    var current: Node = self
    while current != null:
        if current.has_method("get_player_data"):
            return current
        current = current.get_parent()
    return null

func _find_respawn_position(current_position: Vector2) -> Vector2:
    var level_root: Node = self
    while level_root != null and not level_root.has_node("RespawnPoints"):
        level_root = level_root.get_parent()
    if level_root == null:
        return Vector2(320, 560)
    var candidates := level_root.get_node("RespawnPoints").get_children()
    if candidates.is_empty():
        return Vector2(320, 560)
    var best: Marker2D = candidates[0] as Marker2D
    for child in candidates:
        if not (child is Marker2D):
            continue
        var marker := child as Marker2D
        if marker.global_position.x <= current_position.x + 180.0 and marker.global_position.x >= best.global_position.x:
            best = marker
    return best.global_position
