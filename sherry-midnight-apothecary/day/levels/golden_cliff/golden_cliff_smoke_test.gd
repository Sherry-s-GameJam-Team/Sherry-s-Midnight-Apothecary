extends SceneTree

func _initialize() -> void:
    var scene_resource := load("res://day/levels/golden_cliff/golden_cliff.tscn") as PackedScene
    if scene_resource == null:
        push_error("golden_cliff: failed to load scene")
        quit(1)
        return
    var level := scene_resource.instantiate()
    var required_paths := [
        "EntryPoints/default",
        "Player",
        "Player/SherryCollision",
        "Player/SherryPresentation",
        "Player/Camera2D",
        "Player/PotionThrower",
        "WorldBounds",
        "Gameplay/BalanceMechanisms",
        "Gameplay/ExitPortal"
    ]
    for path in required_paths:
        if level.get_node_or_null(path) == null:
            push_error("golden_cliff: missing required node %s" % path)
            level.queue_free()
            quit(1)
            return
    level.queue_free()
    print("golden_cliff smoke test: PASS")
    quit(0)
