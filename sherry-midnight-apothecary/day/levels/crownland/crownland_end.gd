class_name CrownlandEnd
extends DayLevelEnvironment

## Post-boss 王畿 scene scaffold. Dialogue is deliberately not started here;
## later story work can attach it to DialogueAnchor without rebuilding player,
## camera, or collision ownership.

@onready var dialogue_anchor: Marker2D = $DialogueAnchor


func get_dialogue_anchor() -> Marker2D:
	return dialogue_anchor
