class_name StoryEventCatalog
extends Resource

## Order is the deterministic tie-breaker when eligible events share a priority.
@export var events: Array[StoryEventDefinition] = []
