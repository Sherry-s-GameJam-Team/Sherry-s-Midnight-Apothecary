class_name StoryEventTrigger
extends Node

## Attach to an existing interaction controller and call activate() on its
## successful interaction. The node only routes an editor-configured key.
@export var interaction_key: StringName = &""


func activate() -> bool:
	if interaction_key == &"":
		return false
	var current: Node = get_parent()
	while current != null:
		if current.has_method("dispatch_story_event_interaction"):
			return bool(current.call("dispatch_story_event_interaction", interaction_key))
		current = current.get_parent()
	return false
