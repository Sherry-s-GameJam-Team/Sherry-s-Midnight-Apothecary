class_name ControlledTextHint
extends ControlledBase

## 受控文本提示：由 ControllerBase 等外部信号驱动，激活时向顶部 TopHintUI 推送一段文本。

@export var hint_text := ""
@export var hint_id := ""
@export var auto_hide_seconds: float = -1.0


func _on_state_changed(active: bool) -> void:
	if not active:
		return
	if hint_text.is_empty():
		return
	var top_hint := _find_top_hint()
	if top_hint == null:
		return
	var resolved_id := hint_id if not hint_id.is_empty() else "controlled_text_hint_%s" % get_instance_id()
	top_hint.push_text(hint_text, resolved_id, auto_hide_seconds)


func _find_top_hint() -> TopHintUI:
	var current: Node = self
	while current != null:
		var top_hint := current.get_node_or_null("GlobalUI/TopHintUI") as TopHintUI
		if top_hint != null:
			return top_hint
		current = current.get_parent()
	if is_inside_tree() and get_tree() != null:
		return get_tree().root.find_child("TopHintUI", true, false) as TopHintUI
	return null
