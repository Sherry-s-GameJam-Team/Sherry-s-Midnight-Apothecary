extends Area2D
class_name PlayerInteractionArea

signal interacted(body: Node)

@export var player_group: StringName = &"player"
@export var interaction_action: StringName = &"interact"
@export var prompt_text := "E 互动"
@export var one_shot := false

var _candidate: Node = null
var _done := false

@onready var prompt: Label = get_node_or_null("Prompt")

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)
    if prompt:
        prompt.visible = false
        prompt.text = prompt_text

func _unhandled_input(event: InputEvent) -> void:
    if _candidate == null or _done:
        return
    if event.is_action_pressed(interaction_action):
        interacted.emit(_candidate)
        if one_shot:
            _done = true
            if prompt:
                prompt.visible = false
        var vp := get_viewport()
        if vp != null:
            vp.set_input_as_handled()

func _on_body_entered(body: Node) -> void:
    if _is_player(body):
        _candidate = body
        if prompt and not _done:
            prompt.visible = true

func _on_body_exited(body: Node) -> void:
    if body == _candidate:
        _candidate = null
        if prompt:
            prompt.visible = false

func _is_player(body: Node) -> bool:
    if body.is_in_group(player_group):
        return true
    # 对未设置 group 的现有 CharacterBody2D 玩家保持容错。
    return body is CharacterBody2D and ("player" in body.name.to_lower() or "sherry" in body.name.to_lower())
