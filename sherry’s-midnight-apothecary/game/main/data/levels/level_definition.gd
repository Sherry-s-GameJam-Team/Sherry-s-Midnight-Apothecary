class_name LevelDefinition
extends Resource

@export var level_id: StringName
@export var display_name: String
@export var region_id: StringName
## Scene path is stored as plain data instead of an external PackedScene
## dependency. Level scenes reference their LevelDefinition, so storing the
## PackedScene here would create:
## definition.tres -> level.tscn -> definition.tres.
@export_file("*.tscn") var scene_path: String
@export var default_entry_id: StringName = &"default"
@export var music_id: StringName
@export var completion_flag: StringName

## Compatibility accessor used by GameRoot and existing tests. ResourceLoader
## caches the PackedScene after its first successful load.
var scene: PackedScene:
	get:
		if scene_path.is_empty():
			return null
		return ResourceLoader.load(scene_path, "PackedScene") as PackedScene
