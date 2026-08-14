extends Area2D

@onready var label: Label = $Label
func _ready() -> void:
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
    if body.is_in_group("player"):
        label.text = "关卡完成 · 旧旅门已抵达"
