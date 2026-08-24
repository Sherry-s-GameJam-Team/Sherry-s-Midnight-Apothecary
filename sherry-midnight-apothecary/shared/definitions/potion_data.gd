class_name PotionData
extends Resource

@export var id: StringName
## Stable one-based console/save identity for the seven colours and special
## purification formula. Zero is reserved for failed/black potions.
@export_range(0, 99, 1) var numeric_id := 0
@export var display_name: String
@export var color_name: String
## Stable pharmacological family.  This is intentionally separate from the
## persistent resource ID so special formulas can share a colour family.
@export var color_family: StringName
@export var display_color := Color.WHITE
## The existing battle executor key. Keep this stable while world interaction
## moves to effect_tags.
@export var main_effect_id: StringName
## Semantic world-interaction capabilities. New levels must use these instead
## of inspecting resource IDs, colour names, or legacy effect strings.
@export var effect_tags: Array[StringName] = []
## Compatibility names for pre-capability content. They are data only; new
## gameplay must not use them for branching.
@export var legacy_aliases: Array[StringName] = []
@export_range(0.0, 1.0) var spectrum_center_x := 0.5
@export var effect_ranges: Array[Vector2] = []
@export var base_price := 0
@export var icon: Texture2D
@export var heat_profile: HeatProfileData
