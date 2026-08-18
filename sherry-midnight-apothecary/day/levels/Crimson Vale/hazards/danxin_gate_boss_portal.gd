class_name DanxinGateBossPortal
extends DoorPortal

## Danxin Gate boss entrance portal in Crimson Vale Challenge.
## Requires the player to have 3 essential potions equipped (Explosion, Wind, Purification)
## and displays "前有恶灵" warnings via TopHintUI.

const REQUIRED_POTION_GROUPS: Array[Dictionary] = [
	{
		"name": "爆炸药水",
		"ids": [&"red_potion", &"explosion", &"attack"],
		"effect": &"attack"
	},
	{
		"name": "御风药水",
		"ids": [&"cyan_potion", &"wind"],
		"effect": &"wind"
	},
	{
		"name": "净化药水",
		"ids": [&"purification_potion", &"purification"],
		"effect": &"purification"
	}
]


func _ready() -> void:
	destination_level = &"alkeon_boss"
	destination_entry_id = &"default"
	fallback_scene_path = "res://day/levels/Crimson Vale/boss/alkeon_arena.tscn"
	interaction_hint_enabled = true
	super._ready()


func _input(event: InputEvent) -> void:
	if get_tree().has_meta("day_modal_input_locked") or not _player_is_inside or not _is_interact_event(event):
		return

	var missing := _get_missing_required_potions()
	if not missing.is_empty():
		var missing_str := "、".join(missing)
		_show_custom_top_hint("前有恶灵！需要配备【爆炸】、【御风】、【净化】三种药水方可开启丹心门（当前缺少：%s）" % missing_str)
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		return

	# All potions equipped: proceed to Boss Arena!
	super._input(event)


func _show_interaction_hint() -> void:
	var missing := _get_missing_required_potions()
	if missing.is_empty():
		_show_custom_top_hint("前有恶灵！按 [E] 开启丹心门挑战【血叶猎王】")
	else:
		var missing_str := "、".join(missing)
		_show_custom_top_hint("前有恶灵！需要配备【爆炸】、【御风】、【净化】三种药水方可开启丹心门（当前缺少：%s）" % missing_str)


func _get_missing_required_potions() -> Array[String]:
	var pdata := _resolve_player_data()
	var missing: Array[String] = []

	var equipped_ids: Array[StringName] = []
	if pdata != null:
		equipped_ids = pdata.equipped_potion_ids

	# If player has purification potion equipped, it fulfills damage, wind, and purification roles
	var has_purification := false
	for eq_id in equipped_ids:
		var s := String(eq_id).to_lower()
		if s.contains("purification") or s.contains("pure"):
			has_purification = true
			break

	if has_purification:
		return []

	for group in REQUIRED_POTION_GROUPS:
		var matched := false
		var target_ids: Array = group["ids"]
		for eq_id in equipped_ids:
			if eq_id != &"" and target_ids.has(eq_id):
				matched = true
				break
		if not matched:
			missing.append(group["name"])

	return missing


func _resolve_player_data() -> PlayerData:
	var runtime := _find_day_runtime()
	if runtime != null and runtime.has_method("get_player_data"):
		return runtime.get_player_data()
	return null


func _show_custom_top_hint(text: String) -> void:
	var top_hint := _find_top_hint()
	if top_hint != null:
		top_hint.show_interaction_hint(_hint_id(), text)
