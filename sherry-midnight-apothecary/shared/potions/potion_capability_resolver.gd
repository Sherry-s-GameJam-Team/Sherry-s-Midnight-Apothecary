class_name PotionCapabilityResolver
extends RefCounted

## Resolves pharmacological capabilities from a PotionData resource.  The
## fallback table keeps direct-hit tests and un-migrated callers compatible
## while scenes are converted away from ID/string checks.
const LEGACY_CAPABILITIES: Dictionary = {
	&"red_potion": [&"circulation", &"pressure", &"impact", &"blood_resist", &"legacy_attack"],
	&"orange_potion": [&"activation", &"speed", &"machine_drive", &"overclock"],
	&"yellow_potion": [&"buffer", &"pain_relief", &"impact_resist", &"stagger_resist", &"legacy_lightning"],
	&"green_potion": [&"healing", &"regeneration", &"plant_growth", &"repair"],
	&"cyan_potion": [&"stability", &"cooling", &"freeze", &"shield", &"flow_control", &"water_generation"],
	&"blue_potion": [&"purify", &"detox", &"curse_remove", &"magic_cleanse", &"magic_restore", &"legacy_freeze"],
	&"purple_potion": [&"calm", &"mental_guard", &"sleep", &"concealment", &"dream_resist"],
	&"purification_potion": [&"purify", &"purify_strong", &"anti_corruption", &"black_magic_break"],
	&"blue_ice_potion": [&"freeze"],
}


static func has_capability(potion: PotionData, capability: StringName) -> bool:
	if potion == null or capability == &"":
		return false
	if potion.effect_tags.has(capability):
		return true
	# Blue's former freeze interaction remains available only through this
	# compatibility layer while Clockyard content migrates to cyan cooling.
	return capability == &"freeze" and potion.legacy_aliases.has(&"legacy_freeze")


static func hit_has_capability(hit: Dictionary, capability: StringName) -> bool:
	if capability == &"":
		return false
	var potion := hit.get("potion") as PotionData
	if potion != null:
		return has_capability(potion, capability)
	var potion_id := StringName(str(hit.get("potion_id", "")))
	var capabilities: Array = LEGACY_CAPABILITIES.get(potion_id, [])
	return capabilities.has(capability) or (capability == &"freeze" and capabilities.has(&"legacy_freeze"))


static func capabilities_for(potion: PotionData) -> Array[StringName]:
	if potion == null:
		return []
	return potion.effect_tags.duplicate()
