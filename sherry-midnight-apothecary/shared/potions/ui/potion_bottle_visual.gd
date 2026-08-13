class_name PotionBottleVisual
extends Control

const STYLES := [&"health", &"heart", &"ice", &"moon", &"sleep", &"black"]
const BOTTLES := {
	&"health": preload("res://shared/potions/art/health.png"), &"heart": preload("res://shared/potions/art/heart.png"),
	&"ice": preload("res://shared/potions/art/ice.png"), &"moon": preload("res://shared/potions/art/moon.png"),
	&"sleep": preload("res://shared/potions/art/sleep.png"),
	&"black": preload("res://shared/potions/art/black.png"),
}
const COVERS := {
	&"health": preload("res://shared/potions/art/health_cover.png"), &"heart": preload("res://shared/potions/art/heart_cover.png"),
	&"ice": preload("res://shared/potions/art/ice_cover.png"), &"moon": preload("res://shared/potions/art/moon_cover.png"),
	&"sleep": preload("res://shared/potions/art/sleep_cover.png"),
}
const COVER_OFFSETS := {&"heart": Vector2(2.0, 0.0), &"ice": Vector2(2.0, 0.0)}
const COVER_SCALES := {&"heart": Vector2(0.985, 0.985), &"ice": Vector2(0.985, 0.985)}

@onready var liquid: TextureRect = %Liquid
@onready var bottle: TextureRect = %Bottle

func show_instance(potion: PotionData, instance: Dictionary) -> void:
	var style := StringName(str(instance.get("bottle_style_id", "health")))
	if not STYLES.has(style): style = &"health"
	liquid.texture = COVERS.get(style, null)
	bottle.texture = BOTTLES[style]
	liquid.visible = COVERS.has(style)
	liquid.position = COVER_OFFSETS.get(style, Vector2.ZERO)
	liquid.scale = COVER_SCALES.get(style, Vector2.ONE)
	var color := PotionColorResolver.resolve(potion, instance)
	color.a = lerpf(0.42, 0.82, inverse_lerp(0.1, 1.5, clampf(float(instance.get("quality", 1.0)), 0.1, 1.5)))
	liquid.modulate = Color.WHITE
	var material := liquid.material as ShaderMaterial
	if material != null:
		material.set_shader_parameter("liquid_color", color)
