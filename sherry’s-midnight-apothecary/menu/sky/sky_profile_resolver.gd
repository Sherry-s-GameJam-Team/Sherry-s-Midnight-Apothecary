class_name SkyProfileResolver
extends Node

@export var profiles: Array[MenuSkyProfile] = []


func get_profile_for_day(day: int, world_state: Dictionary = {}) -> MenuSkyProfile:
	var override_id := StringName(str(world_state.get("sky_profile_id", "")))
	if override_id != &"":
		for profile: MenuSkyProfile in profiles:
			if profile != null and profile.profile_id == override_id:
				return profile
	var resolved: MenuSkyProfile
	var resolved_start := -1
	for profile: MenuSkyProfile in profiles:
		if profile == null:
			continue
		if profile.start_day <= maxi(day, 1) and profile.start_day > resolved_start:
			resolved = profile
			resolved_start = profile.start_day
	if resolved == null and not profiles.is_empty():
		resolved = profiles[0]
	return resolved


func get_profile_for_menu(has_save: bool, mode: GameFlow.Mode) -> MenuSkyProfile:
	var profile_id := &"night_default" if has_save and mode == GameFlow.Mode.NIGHT else &"day_01_default"
	var resolved := get_profile_by_id(profile_id)
	return resolved if resolved != null else get_profile_for_day(1)


func get_profile_by_id(profile_id: StringName) -> MenuSkyProfile:
	for profile: MenuSkyProfile in profiles:
		if profile != null and profile.profile_id == profile_id:
			return profile
	return null


func get_profile_index(profile: MenuSkyProfile) -> int:
	return profiles.find(profile)
