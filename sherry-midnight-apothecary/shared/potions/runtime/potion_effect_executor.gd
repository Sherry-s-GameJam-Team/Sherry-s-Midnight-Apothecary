class_name PotionEffectExecutor
extends Node2D

@export var tuning: PotionEffectTuning


func execute(potion: PotionData, payload: Dictionary, impact_point: Vector2, impact_normal: Vector2, source: Node) -> void:
	if potion == null or potion.id == &"black_potion" or potion.main_effect_id == &"":
		return
	var secondary_id := StringName(str(payload.get("secondary_effect_id", "")))
	var secondary_multiplier := clampf(float(payload.get("secondary_effect_multiplier", 0.0)), 0.0, 1.0)
	var charge_multiplier := clampf(float(payload.get("effect_stack_multiplier", 1.0)), 1.0, 4.0)
	var primary_effects: Array[StringName] = potion.combat_effect_ids if not potion.combat_effect_ids.is_empty() else [potion.main_effect_id]
	for effect_id: StringName in primary_effects:
		var multiplier := charge_multiplier
		if secondary_id == effect_id:
			multiplier *= 1.0 + secondary_multiplier
		_apply_effect(effect_id, multiplier, payload, impact_point, impact_normal, source, potion)
	if secondary_id != &"" and secondary_multiplier > 0.0 and not primary_effects.has(secondary_id):
		_apply_effect(secondary_id, secondary_multiplier * charge_multiplier, payload, impact_point, impact_normal, source, potion)


func _apply_effect(effect_id: StringName, effect_multiplier: float, payload: Dictionary, point: Vector2, normal: Vector2, source: Node, potion: PotionData) -> void:
	if tuning == null:
		return
	var shape := CircleShape2D.new()
	shape.radius = tuning.effect_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, point)
	query.collision_mask = tuning.effect_collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var results := get_world_2d().direct_space_state.intersect_shape(query, 64)
	var handled: Dictionary = {}
	for hit: Dictionary in results:
		var target: Object = hit.get("collider")
		if target == null or target == source or handled.has(target.get_instance_id()):
			continue
		if not _target_accepts_effect(target, effect_id):
			continue
		handled[target.get_instance_id()] = true
		var context := _make_context(effect_id, effect_multiplier, payload, point, normal, source, potion)
		_dispatch(target, effect_id, context)


func _make_context(effect_id: StringName, multiplier: float, payload: Dictionary, point: Vector2, normal: Vector2, source: Node, potion: PotionData) -> Dictionary:
	var potency := float(payload.get("potency", 1.0))
	var quality := float(payload.get("quality", 1.0))
	var duration_factor := float(payload.get("duration", 1.0))
	var context := {
		"effect_id": effect_id,
		"source": source,
		"impact_point": point,
		"impact_normal": normal,
		"radius": tuning.effect_radius,
		"multiplier": multiplier,
		"potency": potency,
		"quality": quality,
		"duration": tuning.base_status_duration * duration_factor,
		"payload": payload,
		"potion": potion,
		"capabilities": PotionCapabilityResolver.capabilities_for(potion),
	}
	match effect_id:
		&"attack":
			context["amount"] = tuning.attack_damage * potency * quality * multiplier
			context["knockback"] = tuning.attack_knockback * potency * multiplier
		&"lightning_meteor":
			context["amount"] = tuning.attack_damage * 1.35 * potency * quality * multiplier
			context["knockback"] = tuning.attack_knockback * 1.2 * potency * multiplier
			context["strike_count"] = 3
		&"speed": context["amount"] = tuning.speed_bonus * potency * multiplier
		&"healing": context["amount"] = tuning.healing_amount * potency * quality * multiplier
		&"shield": context["amount"] = tuning.shield_amount * potency * quality * multiplier
		&"mana": context["amount"] = tuning.mana_amount * potency * quality * multiplier
		&"buffer":
			context["amount"] = multiplier
			context["damage_reduction"] = tuning.buffer_damage_reduction
			context["knockback_reduction"] = tuning.buffer_knockback_reduction
		&"concealment", &"calm", &"purify": context["amount"] = multiplier
	return context


func _dispatch(target: Object, effect_id: StringName, context: Dictionary) -> void:
	if target is Node and effect_id == &"calm":
		(target as Node).set_meta("potion_calmed_until_ms", Time.get_ticks_msec() + roundi(float(context.get("duration", 0.0)) * 1000.0))
	if target.has_method("apply_potion_effect"):
		target.call("apply_potion_effect", effect_id, context)
		return
	var method_name := StringName("apply_potion_%s" % effect_id)
	if target.has_method(method_name):
		target.call(method_name, context)
		return


func _target_accepts_effect(target: Object, effect_id: StringName) -> bool:
	if target is not Node:
		return false
	var node := target as Node
	var friendly := node.is_in_group("potion_friendly") or node.is_in_group("player") or node.is_in_group("friendly")
	if effect_id in [&"speed", &"healing", &"shield", &"mana", &"concealment", &"buffer"]:
		return friendly
	if effect_id == &"calm":
		return not friendly
	return true
