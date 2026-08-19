class_name DeveloperConsole
extends Control

const POTION_IDS_BY_NUMBER: Array[StringName] = [
	&"red_potion",
	&"orange_potion",
	&"yellow_potion",
	&"green_potion",
	&"cyan_potion",
	&"blue_potion",
	&"purple_potion",
	&"purification_potion",
]

var night_runtime: Node
var day_runtime: Node
var day_scene: Node
var alchemy_runtime_override: Node
var _previous_tree_paused := false
var _history: Array[String] = []
var _history_index := 0
var _welcomed := false
var _toggle_key_was_down := false
var _fallback_player_data: PlayerData

const ALL_DAY_LEVEL_PATHS: Array[String] = [
	"res://day/levels/market/town/town_level.tres",
	"res://day/levels/home/home_level.tres",
	"res://day/levels/home/bedroom_level.tres",
	"res://day/levels/forest/forest_level.tres",
	"res://day/levels/forest/interior/forest_interior_level.tres",
	"res://day/levels/forest/crown/forest_crown_level.tres",
	"res://day/levels/lake/lake_level.tres",
	"res://day/levels/grassland/grassland_level.tres",
	"res://day/levels/grassland/emerald_field_level.tres",
	"res://day/levels/golden_cliff/golden_cliff_level.tres",
	"res://day/levels/golden_cliff/village/village_level.tres",
	"res://day/levels/lake_bottom/lake_bottom_level.tres",
	"res://day/levels/lake_bottom/gate_chamber_level.tres",
	"res://day/levels/Crimson Vale/crimson_vale_level.tres",
	"res://day/levels/Crimson Vale/crimson_vale_challenge_level.tres",
	"res://day/levels/Crimson Vale/alkeon_boss_level.tres",
	"res://day/levels/Aurem Clockyard/aurem_clockyard_level.tres",
	"res://day/levels/Aurem Clockyard/aurem_clockyard_inside_level.tres",
	"res://day/levels/Vespervale/vespervale_garden_level.tres",
	"res://day/levels/Vespervale/vespervale_inner_level.tres",
	"res://day/levels/Vespervale/vespervale_runner_level.tres",
	"res://day/levels/lake/lake_cliff_underwater_level.tres",
	"res://day/levels/cliff/cliff_level.tres",
	"res://day/levels/lakebed/lakebed_level.tres",
	"res://day/levels/grassland/grassland_proto_level.tres",
	"res://day/minigames/miasma_purifier/miasma_purifier_level.tres",
	"res://day/interactables/control_system/control_system_demo_level.tres",
]

const SCENE_ALIASES: Dictionary = {
	"town": "market",
	"market": "market",
	"流明街": "market",
	"集市": "market",
	"城镇": "market",
	"市集": "market",

	"home": "home",
	"shop": "home",
	"apothecary": "home",
	"工坊": "home",
	"家": "home",
	"药水铺": "home",

	"bedroom": "bedroom",
	"bed": "bedroom",
	"room": "bedroom",
	"卧室": "bedroom",
	"二楼": "bedroom",
	"二楼卧室": "bedroom",

	"forest": "forest",
	"raintree": "forest",
	"rain_tree": "forest",
	"tree": "forest",
	"常霁云林": "forest",
	"雨树林": "forest",
	"树林": "forest",
	"森林": "forest",

	"forest_interior": "forest_interior",
	"interior": "forest_interior",
	"luca": "forest_interior",
	"tree_house": "forest_interior",
	"treehouse": "forest_interior",
	"云下树屋": "forest_interior",
	"树屋": "forest_interior",
	"卢卡工坊": "forest_interior",

	"forest_crown": "forest_crown",
	"crown": "forest_crown",
	"rooftop": "forest_crown",
	"树冠": "forest_crown",
	"天台": "forest_crown",
	"树冠天台": "forest_crown",

	"lake": "lake",
	"mirror_lake": "lake",
	"镜湖": "lake",
	"湖": "lake",

	"grassland": "grassland",
	"grass": "grassland",
	"emerald": "grassland",
	"翡翠原": "grassland",
	"草地": "grassland",
	"平原": "grassland",

	"emerald_field": "emerald_field",
	"field": "emerald_field",
	"miasma": "emerald_field",
	"翡翠原野": "emerald_field",
	"原野": "emerald_field",
	"瘴气": "emerald_field",

	"golden_cliff": "golden_cliff",
	"cliff": "golden_cliff",
	"烁金横崖": "golden_cliff",
	"横崖": "golden_cliff",
	"断崖": "golden_cliff",
	"烁金": "golden_cliff",

	"golden_cliff_village": "golden_cliff_village",
	"village": "golden_cliff_village",
	"涟汀村": "golden_cliff_village",
	"废村": "golden_cliff_village",
	"村庄": "golden_cliff_village",

	"lake_bottom": "lake_bottom",
	"underwater": "lake_bottom",
	"lakebed": "lake_bottom",
	"湖床": "lake_bottom",
	"湖底": "lake_bottom",
	"沉没回廊": "lake_bottom",
	"阿里特之泪": "lake_bottom",

	"gate_chamber": "gate_chamber",
	"chamber": "gate_chamber",
	"gate": "gate_chamber",
	"维护站": "gate_chamber",
	"密室": "gate_chamber",
	"旧旅门维护站": "gate_chamber",
	"封印大门": "gate_chamber",

	"crimson_vale": "crimson_vale",
	"crimson": "crimson_vale",
	"vale": "crimson_vale",
	"猩红谷地": "crimson_vale",
	"猩红": "crimson_vale",

	"crimson_vale_challenge": "crimson_vale_challenge",
	"challenge": "crimson_vale_challenge",
	"vale_challenge": "crimson_vale_challenge",
	"挑战关": "crimson_vale_challenge",
	"猩红挑战": "crimson_vale_challenge",

	"alkeon_boss": "alkeon_boss",
	"alkeon": "alkeon_boss",
	"boss2": "alkeon_boss",
	"boss_2": "alkeon_boss",
	"alkeon_arena": "alkeon_boss",
	"血叶猎王": "alkeon_boss",
	"阿尔凯昂": "alkeon_boss",
	"猎王": "alkeon_boss",

	"aurem_clockyard": "aurem_clockyard",
	"clockyard": "aurem_clockyard",
	"aurem": "aurem_clockyard",
	"clock": "aurem_clockyard",
	"奥勒姆钟庭": "aurem_clockyard",
	"钟庭": "aurem_clockyard",
	"奥勒姆": "aurem_clockyard",

	"aurem_clockyard_inside": "aurem_clockyard_inside",
	"clockyard_inside": "aurem_clockyard_inside",
	"clocktower_inside": "aurem_clockyard_inside",
	"钟塔内部": "aurem_clockyard_inside",
	"钟楼内部": "aurem_clockyard_inside",
	"发条室": "aurem_clockyard_inside",
	"齿轮井": "aurem_clockyard_inside",
	"钟摆厅": "aurem_clockyard_inside",
	"校时台": "aurem_clockyard_inside",

	"lake_cliff_underwater": "lake_cliff_underwater",
	"lake_underwater": "lake_cliff_underwater",
	"underwater_tunnel": "lake_cliff_underwater",
	"cliff_underwater": "lake_cliff_underwater",
	"水下暗道": "lake_cliff_underwater",
	"水下通道": "lake_cliff_underwater",
	"水下升降梯": "lake_cliff_underwater",

	"shimmering_cliff": "cliff",
	"resonance_cliff": "cliff",
	"鸣晶断崖": "cliff",
	"烁金断崖": "cliff",

	"lakebed_proto": "lakebed",
	"湖床遗迹": "lakebed",
	"湖床原型": "lakebed",

	"grass_proto": "grassland_proto",
	"grassland_level": "grassland_proto",
	"平原原型": "grassland_proto",

	"purifier_minigame": "miasma_purifier",
	"miasma_game": "miasma_purifier",
	"净化小游戏": "miasma_purifier",
	"瘴气小游戏": "miasma_purifier",

	"mechanisms_demo": "control_system_demo",
	"control_demo": "control_system_demo",
	"机关演示": "control_system_demo",
	"机关控制": "control_system_demo",

	"vespervale": "vespervale_garden",
	"vespervale_garden": "vespervale_garden",
	"garden": "vespervale_garden",
	"暮息谷": "vespervale_garden",
	"暮息庭院": "vespervale_garden",
	"花园": "vespervale_garden",
	"庭院": "vespervale_garden",

	"vespervale_inner": "vespervale_inner",
	"inner": "vespervale_inner",
	"病栋": "vespervale_inner",
	"回廊": "vespervale_inner",
	"病栋回廊": "vespervale_inner",
	"梦疗院": "vespervale_inner",

	"vespervale_runner": "vespervale_runner",
	"runner": "vespervale_runner",
	"parkour": "vespervale_runner",
	"跑酷": "vespervale_runner",
	"疾驰": "vespervale_runner",
	"疾驰回廊": "vespervale_runner",
	"梦境疾驰": "vespervale_runner",
}

const FALLBACK_INGREDIENT_PATHS: Array[String] = [
	"res://shared/definitions/data/ingredients/herdsmans_loaf_bush.tres",
	"res://shared/definitions/data/ingredients/stardust_puffy_lion.tres",
	"res://shared/definitions/data/ingredients/grail_lily.tres",
	"res://shared/definitions/data/ingredients/dew_flask_herb.tres",
	"res://shared/definitions/data/ingredients/old_mans_noose.tres",
	"res://shared/definitions/data/ingredients/praise_star_maple.tres",
	"res://shared/definitions/data/ingredients/amber_root.tres",
	"res://shared/definitions/data/ingredients/blue_bell.tres",
	"res://shared/definitions/data/ingredients/mist_leaf.tres",
	"res://shared/definitions/data/ingredients/moon_mint.tres",
	"res://shared/definitions/data/ingredients/red_berry.tres",
	"res://shared/definitions/data/ingredients/star_lavender.tres",
	"res://shared/definitions/data/ingredients/sun_daisy.tres",
	"res://shared/definitions/data/ingredients/violet_thistle.tres",
]

@onready var output: RichTextLabel = %Output
@onready var command_input: LineEdit = %CommandInput


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	set_process(true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()
	command_input.text_submitted.connect(_on_command_submitted)


func setup(runtime: Node) -> void:
	day_runtime = null
	day_scene = null
	night_runtime = runtime
	alchemy_runtime_override = runtime.alchemy_runtime if runtime != null else null


func setup_day(runtime: Node) -> void:
	night_runtime = null
	alchemy_runtime_override = null
	day_scene = null
	day_runtime = runtime


func setup_day_scene(scene: Node) -> void:
	night_runtime = null
	alchemy_runtime_override = null
	day_runtime = null
	day_scene = scene


func setup_alchemy(runtime: Node) -> void:
	day_runtime = null
	day_scene = null
	night_runtime = null
	alchemy_runtime_override = runtime


func open() -> void:
	if visible:
		command_input.grab_focus()
		return
	_previous_tree_paused = get_tree().paused
	if not _uses_live_day_controls():
		get_tree().paused = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	show()
	move_to_front()
	if not _welcomed:
		_write("开发控制台已启用。输入 help 查看命令。", Color("#e7c878"))
		_welcomed = true
	command_input.clear()
	command_input.grab_focus()


func close() -> void:
	if not visible:
		return
	command_input.release_focus()
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().paused = _previous_tree_paused


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func _process(_delta: float) -> void:
	# Polling remains reliable when an IME or another UI consumes the key event.
	var toggle_key_down := (
		Input.is_physical_key_pressed(KEY_QUOTELEFT)
		or Input.is_key_pressed(KEY_QUOTELEFT)
		or Input.is_key_pressed(KEY_ASCIITILDE)
		or Input.is_key_pressed(KEY_F1)
	)
	if toggle_key_down and not _toggle_key_was_down:
		toggle()
	_toggle_key_was_down = toggle_key_down


func _input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	if _is_console_key(key_event):
		_toggle_key_was_down = true
		toggle()
		get_viewport().set_input_as_handled()
		return
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return


func _is_console_key(event: InputEventKey) -> bool:
	return (
		event.keycode == KEY_F1
		or event.physical_keycode == KEY_F1
		or event.key_label == KEY_F1
		or event.keycode == KEY_QUOTELEFT
		or event.physical_keycode == KEY_QUOTELEFT
		or event.key_label == KEY_QUOTELEFT
		or event.keycode == KEY_ASCIITILDE
		or event.key_label == KEY_ASCIITILDE
		or event.unicode == 96
		or event.unicode == 126
	)


func _uses_live_day_controls() -> bool:
	return day_runtime != null or day_scene != null


func _exit_tree() -> void:
	if command_input != null and command_input.is_inside_tree() and command_input.has_focus():
		command_input.release_focus()
	if visible and get_tree() != null:
		get_tree().paused = _previous_tree_paused


func execute_command(raw_command: String) -> String:
	var command := raw_command.strip_edges()
	if command.is_empty():
		return ""
	_write("> %s" % command, Color("#a6d9ff"))
	var parts := command.split(" ", false)
	var verb := parts[0].to_lower()
	var result := ""
	match verb:
		"help", "?":
			result = _help_text()
		"status":
			result = _status_text()
		"get":
			result = _get_command(parts)
		"set":
			result = _set_command(parts, false)
		"add":
			result = _set_command(parts, true)
		"give":
			result = _inventory_command(parts, 1)
		"take":
			result = _inventory_command(parts, -1)
		"potion":
			result = _potion_command(parts)
		"temp":
			result = _temperature_command(parts)
		"day", "night":
			result = _mode_command(parts)
		"scene", "level":
			result = _scene_command(parts)
		"boss", "boos":
			result = _boss_command(parts)
		"title":
			result = _title_command(parts)
		"to":
			result = _environment_texture_command(parts)
		"clear":
			if output != null:
				output.clear()
			return ""
		"close":
			close()
			return ""
		_:
			result = "未知命令：%s。输入 help 查看可用命令。" % verb
	_write(result, Color("#e6dfcf") if not result.begins_with("错误") else Color("#ff8d82"))
	return result


func _mode_command(parts: PackedStringArray) -> String:
	if parts.size() != 1:
		return "错误：用法 day 或 night"
	var app_root: Node = get_node_or_null("/root/AppRoot")
	if app_root == null:
		return "错误：GameFlow 尚未初始化。"
	var flow: Node = app_root.get("game_flow")
	if flow == null:
		return "错误：GameFlow 尚未初始化。"
	var target_mode: int = 0 if parts[0].to_lower() == "day" else 1
	if flow.get("current_mode") == target_mode:
		return "mode = %s" % parts[0].to_lower()
	if not flow.has_method("debug_switch_mode") or not flow.call("debug_switch_mode", target_mode):
		return "错误：无法切换到 %s。" % parts[0].to_lower()
	return "mode = %s" % parts[0].to_lower()


func _get_command(parts: PackedStringArray) -> String:
	if parts.size() != 2:
		return "错误：用法 get <money|debt|health|max_health|day|temp|inventory.ID|potions.ID>"
	var path := parts[1].to_lower()
	var player := _player()
	if player == null:
		return "错误：PlayerData 尚未初始化。"
	match path:
		"money":
			return "money = %d" % player.money
		"debt":
			return "debt = %d" % player.debt
		"health":
			return "health = %d" % player.health
		"max_health":
			return "max_health = %d" % player.max_health
		"day":
			return "day = %d" % _day()
		"temp":
			var alchemy := _alchemy()
			return "temp = %.1f" % alchemy.temperature if alchemy != null else "错误：当前不在夜间炼药场景。"
	if path.begins_with("inventory."):
		var ingredient_id := StringName(path.trim_prefix("inventory."))
		return "inventory.%s = %d" % [ingredient_id, int(player.inventory.get(ingredient_id, 0))]
	if path.begins_with("potions."):
		var potion_id := StringName(path.trim_prefix("potions."))
		var instances: Array = player.potions.get(potion_id, [])
		return "potions.%s = %d" % [potion_id, instances.size()]
	return "错误：不支持的参数路径 %s。" % path


func _set_command(parts: PackedStringArray, additive: bool) -> String:
	if parts.size() != 3 or not parts[2].is_valid_float():
		return "错误：用法 %s <money|debt|health|max_health|day|temp|inventory.ID> <数值>" % parts[0]
	var path := parts[1].to_lower()
	var number := float(parts[2])
	if path == "temp":
		var alchemy := _alchemy()
		if alchemy == null:
			return "错误：当前不在夜间炼药场景。"
		alchemy.set_temperature(alchemy.temperature + number if additive else number)
		return "temp = %.1f" % alchemy.temperature
	var player := _player()
	if player == null:
		return "错误：PlayerData 尚未初始化。"
	var integer := roundi(number)
	match path:
		"money":
			player.money = player.money + integer if additive else integer
			return "money = %d" % player.money
		"debt":
			player.debt = maxi(player.debt + integer if additive else integer, 0)
			return "debt = %d" % player.debt
		"max_health":
			player.set_max_health(player.max_health + integer if additive else integer)
			return "max_health = %d" % player.max_health
		"health":
			player.set_health(player.health + integer if additive else integer)
			return "health = %d" % player.health
	if path.begins_with("inventory."):
		var ingredient_id := StringName(path.trim_prefix("inventory."))
		var old_count := int(player.inventory.get(ingredient_id, 0))
		var new_count := maxi(old_count + integer if additive else integer, 0)
		_set_inventory_count(player, ingredient_id, new_count)
		_refresh_alchemy()
		return "inventory.%s = %d" % [ingredient_id, new_count]
	return "错误：不能设置参数 %s。" % path


func _inventory_command(parts: PackedStringArray, direction: int) -> String:
	if parts.size() < 2 or parts.size() > 3:
		return "错误：用法 %s <植物序号|ingredient_id> [数量]" % parts[0]
	var count := 1
	if parts.size() == 3:
		if not parts[2].is_valid_int():
			return "错误：数量必须是整数。"
		count = maxi(int(parts[2]), 0)
	var player := _player()
	if player == null:
		return "错误：PlayerData 尚未初始化。"
	var ingredient_id := StringName(parts[1])
	if parts[1].is_valid_int():
		var alchemy := _alchemy()
		if alchemy == null or alchemy.ingredients.is_empty():
			var plant_number := int(parts[1])
			if plant_number < 1 or plant_number > FALLBACK_INGREDIENT_PATHS.size():
				return "错误：植物序号超出范围。"
			var loaded_res = load(FALLBACK_INGREDIENT_PATHS[plant_number - 1])
			if loaded_res != null and "id" in loaded_res:
				ingredient_id = loaded_res.id
			else:
				return "错误：第 %d 株植物的数据无法加载。" % plant_number
			var new_count := maxi(int(player.inventory.get(ingredient_id, 0)) + count * direction, 0)
			_set_inventory_count(player, ingredient_id, new_count)
			return "inventory.%s = %d" % [ingredient_id, new_count]
		var plant_number := int(parts[1])
		if plant_number < 1 or plant_number > alchemy.ingredients.size():
			return "错误：植物序号必须在 1–%d 之间。" % alchemy.ingredients.size()
		var ingredient := alchemy.ingredients[plant_number - 1] as IngredientData
		if ingredient == null or ingredient.id == &"":
			return "错误：第 %d 株植物的数据无效。" % plant_number
		ingredient_id = ingredient.id
	var new_count := maxi(int(player.inventory.get(ingredient_id, 0)) + count * direction, 0)
	_set_inventory_count(player, ingredient_id, new_count)
	_refresh_alchemy()
	return "inventory.%s = %d" % [ingredient_id, new_count]


func _potion_command(parts: PackedStringArray) -> String:
	if parts.size() < 2 or parts.size() > 4:
		return "错误：用法 potion <potion_id> [数量] [品质]"
	var count := 1
	var quality := 1.0
	if parts.size() >= 3:
		if not parts[2].is_valid_int():
			return "错误：数量必须是整数。"
		count = maxi(int(parts[2]), 0)
	if parts.size() == 4:
		if not parts[3].is_valid_float():
			return "错误：品质必须是数字。"
		quality = clampf(float(parts[3]), 0.1, 1.5)
	var player := _player()
	if player == null:
		return "错误：PlayerData 尚未初始化。"
	var potion_id := _resolve_potion_id(parts[1])
	if potion_id == &"":
		return "错误：药水序号必须在 1–%d 之间。" % POTION_IDS_BY_NUMBER.size()
	var instances: Array = player.potions.get(potion_id, [])
	for _index in count:
		instances.append({
			"potion_id": str(potion_id),
			"mixed_x": 0.0,
			"secondary_effect_id": "",
			"quality": quality,
			"created_day": _day(),
		})
	player.potions[potion_id] = instances
	return "potions.%s = %d" % [potion_id, instances.size()]


func _temperature_command(parts: PackedStringArray) -> String:
	if parts.size() != 2 or not parts[1].is_valid_float():
		return "错误：用法 temp <0–100>"
	var alchemy := _alchemy()
	if alchemy == null:
		return "错误：当前不在夜间炼药场景。"
	alchemy.set_temperature(float(parts[1]))
	return "temp = %.1f" % alchemy.temperature


func _get_available_day_levels() -> Array[LevelData]:
	if day_runtime != null:
		var levels_prop = day_runtime.get("LEVELS")
		if levels_prop is Array and not levels_prop.is_empty():
			var levels_arr: Array[LevelData] = []
			for item in levels_prop:
				if item is LevelData:
					levels_arr.append(item)
			if not levels_arr.is_empty():
				return levels_arr
	var loaded_levels: Array[LevelData] = []
	for path in ALL_DAY_LEVEL_PATHS:
		var res = load(path) as LevelData
		if res != null:
			loaded_levels.append(res)
	return loaded_levels


func _format_scene_list() -> String:
	var levels := _get_available_day_levels()
	var lines: PackedStringArray = ["可用日间场景序号对照列表（支持 scene <序号 1-%d|场景ID|中文别名>）：" % levels.size()]
	for i in levels.size():
		var lvl: LevelData = levels[i]
		var alias_hint := ""
		match str(lvl.id):
			"market": alias_hint = " / town"
			"home": alias_hint = " / shop"
			"bedroom": alias_hint = " / room"
			"forest": alias_hint = " / raintree"
			"forest_interior": alias_hint = " / interior / luca"
			"forest_crown": alias_hint = " / crown"
			"lake": alias_hint = " / mirror_lake"
			"grassland": alias_hint = " / grass"
			"emerald_field": alias_hint = " / miasma"
			"golden_cliff": alias_hint = " / cliff"
			"golden_cliff_village": alias_hint = " / village"
			"lake_bottom": alias_hint = " / underwater"
			"gate_chamber": alias_hint = " / chamber"
			"crimson_vale": alias_hint = " / vale"
			"crimson_vale_challenge": alias_hint = " / challenge"
			"alkeon_boss": alias_hint = " / boss 2"
			"aurem_clockyard": alias_hint = " / clockyard"
			"aurem_clockyard_inside": alias_hint = " / clockyard_inside / inside"
			"lake_cliff_underwater": alias_hint = " / underwater_tunnel"
			"cliff": alias_hint = " / shimmering_cliff"
			"lakebed": alias_hint = " / lakebed_proto"
			"grassland_proto": alias_hint = " / grass_proto"
			"miasma_purifier": alias_hint = " / purifier_minigame"
			"control_system_demo": alias_hint = " / mechanisms_demo"
			"vespervale_garden": alias_hint = " / vespervale / garden"
		lines.append("[%d] %s (%s%s)" % [i + 1, lvl.id, lvl.display_name, alias_hint])
	return "\n".join(lines)


func _resolve_target_level(query: String) -> LevelData:
	var levels := _get_available_day_levels()
	var raw := query.strip_edges()
	var lower := raw.to_lower()

	# 1. Number lookup (1-based index)
	if raw.is_valid_int():
		var idx := int(raw) - 1
		if idx >= 0 and idx < levels.size():
			return levels[idx]
		return null

	# 2. Predefined alias mapping
	var target_id := ""
	if SCENE_ALIASES.has(lower):
		target_id = SCENE_ALIASES[lower]
	elif SCENE_ALIASES.has(raw):
		target_id = SCENE_ALIASES[raw]

	if not target_id.is_empty():
		for lvl in levels:
			if str(lvl.id).to_lower() == target_id:
				return lvl

	# 3. Exact ID match
	for lvl in levels:
		if str(lvl.id).to_lower() == lower:
			return lvl

	# 4. Exact Display Name match
	for lvl in levels:
		if lvl.display_name.to_lower() == lower or lvl.display_name == raw:
			return lvl

	# 5. Fuzzy match: contains in ID or DisplayName or DisasterName
	for lvl in levels:
		if str(lvl.id).to_lower().contains(lower) or lvl.display_name.to_lower().contains(lower) or (not lvl.disaster_name.is_empty() and lvl.disaster_name.to_lower().contains(lower)):
			return lvl

	return null


func _scene_command(parts: PackedStringArray) -> String:
	if parts.size() == 1 or (parts.size() == 2 and parts[1].to_lower() in ["list", "help", "?", "all"]):
		return _format_scene_list()
	if parts.size() != 2:
		return "错误：用法 scene <序号 1-%d|场景ID|中文别名> 或 scene list" % _get_available_day_levels().size()

	var target_level := _resolve_target_level(parts[1])
	if target_level == null:
		var levels_count := _get_available_day_levels().size()
		if parts[1].is_valid_int():
			return "错误：场景序号超出范围（可用：1–%d）。输入 scene list 查看全部。" % levels_count
		return "错误：未知场景 \"%s\"。输入 scene list 查看可用序号与场景对照。" % parts[1]

	if day_runtime != null:
		if not day_runtime.switch_to_level(str(target_level.id)):
			return "错误：无法切换到场景 %s。" % target_level.display_name
		return "scene = %s" % day_runtime.current_level.display_name

	# Standalone mode fallback (direct scene change)
	if target_level.content_scene == null:
		return "错误：场景 %s 没有配置有效的内容场景。" % target_level.display_name

	var tree := get_tree()
	if tree == null:
		return "错误：SceneTree 不可用。"

	var scene_path := target_level.content_scene.resource_path
	if not scene_path.is_empty():
		if tree.change_scene_to_file(scene_path) != OK:
			return "错误：无法切换到场景文件 %s。" % scene_path
	else:
		if tree.change_scene_to_packed(target_level.content_scene) != OK:
			return "错误：无法切换到场景 %s。" % target_level.display_name
	return "scene = %s" % target_level.display_name


func _title_command(parts: PackedStringArray) -> String:
	if parts.size() != 1:
		return "错误：用法 title"
	if day_runtime == null:
		return "错误：标题动画仅由 DayRuntime 提供，独立关卡场景不支持。"
	if not day_runtime.replay_scene_title():
		return "错误：当前场景已禁用标题动画。"
	return "标题动画已播放：%s" % day_runtime.current_level.display_name


func _environment_texture_command(parts: PackedStringArray) -> String:
	if parts.size() != 2 or parts[1].to_lower() not in ["normal", "corrupted"]:
		return "Error: use to <normal|corrupted>"
	var environment := _texture_switch_environment()
	if environment == null:
		return "Error: the current scene does not support texture-state switching."
	var corrupted := parts[1].to_lower() == "corrupted"
	environment.call("set_corrupted", corrupted)
	return "environment = %s" % ("corrupted" if corrupted else "normal")


func _texture_switch_environment() -> Node:
	if day_scene != null and day_scene.has_method("set_corrupted"):
		return day_scene
	if day_runtime != null and day_runtime.level_slot != null:
		for child in day_runtime.level_slot.get_children():
			if child.has_method("set_corrupted"):
				return child
	var current := get_parent()
	while current != null:
		if current.has_method("set_corrupted"):
			return current
		current = current.get_parent()
	return null


func _status_text() -> String:
	if day_runtime != null:
		var level: LevelData = day_runtime.current_level
		if level == null:
			return "错误：日间场景尚未初始化。"
		return "day=%d  mode=DAY  location=%s  disaster=%s" % [
			day_runtime.day,
			level.display_name,
			level.disaster_name,
		]
	if day_scene != null:
		return "day=1  mode=DAY  scene=%s  title=runtime-only" % day_scene.debug_scene_id
	var player := _player()
	if player == null or _alchemy() == null:
		return "错误：游戏尚未初始化。"
	return "day=%d  mode=NIGHT  health=%d/%d  money=%d  debt=%d  ingredients=%d  potion_types=%d" % [
		_day(),
		player.health,
		player.max_health,
		player.money,
		player.debt,
		player.inventory.size(),
		player.potions.size(),
	]


func _boss_command(parts: PackedStringArray) -> String:
	if parts.size() < 2:
		return "用法：boss <2> (例如：boss 2 进入血叶猎王挑战并装备无限药水)"

	var boss_arg := parts[1].to_lower()
	match boss_arg:
		"2", "alkeon", "alkeon_boss", "alkeon_arena", "deer", "blood_leaf":
			var player := _player()
			if player != null:
				_equip_infinite_battle_potions(player)

			var arena_path := "res://day/levels/Crimson Vale/boss/alkeon_arena.tscn"
			close()

			var tree := get_tree()
			if tree != null:
				tree.change_scene_to_file(arena_path)
			return "已进入【血叶猎王·阿尔凯昂】Boss 挑战，并装备无限药水！"
		_:
			return "错误：未知 Boss 序号 %s。当前可用：boss 2 (血叶猎王·阿尔凯昂)。" % boss_arg


func _equip_infinite_battle_potions(player: PlayerData) -> void:
	if player == null:
		return
	var battle_potions: Array[StringName] = [
		&"purification_potion",
		&"cyan_potion",
		&"red_potion",
		&"orange_potion",
		&"yellow_potion",
		&"green_potion",
		&"blue_potion",
		&"purple_potion"
	]
	player.potions.clear()
	for pot_id in battle_potions:
		var instances: Array[Dictionary] = []
		for i in range(99):
			instances.append({
				"potion_id": str(pot_id),
				"instance_uid": "%s_%d" % [str(pot_id), i],
				"remaining_dose": 1.0,
				"potency": 1.5,
				"quality": 1.5,
				"duration": 1.0,
				"thermal_score": 1.0,
				"created_day": _day(),
			})
		player.potions[pot_id] = instances

	player.equipped_potion_ids = [
		&"red_potion",
		&"cyan_potion",
		&"purification_potion",
		&"orange_potion"
	]


func _help_text() -> String:
	return """Day scene commands:
  scene [list] - 查看全部可用日间场景序号对照列表
  scene <序号 1-17 | 场景ID | 中文别名> - 切换到指定场景 (如 scene 17 或 scene 钟庭)
  boss 2 (或 boos 2) - 直达血叶猎王Boss战并装备无限药水
  title - 重新播放当前场景标题动画
  to normal - 切换环境为常态
  to corrupted - 切换环境为异变态

Other commands:
  day, night, status, get, set, add, give, take, potion, boss, temp, clear, close"""


func _player() -> PlayerData:
	if day_runtime != null:
		return day_runtime.call("get_player_data") as PlayerData
	if day_scene != null and day_scene.has_method("get_player_data"):
		return day_scene.call("get_player_data") as PlayerData
	if night_runtime != null:
		if night_runtime.player_data == null:
			night_runtime.configure(PlayerData.new(), night_runtime.day)
			_write("NightRuntime 未经 GameFlow 配置，已创建独立测试用 PlayerData。", Color("#e7c878"))
		return night_runtime.player_data
	if alchemy_runtime_override != null and alchemy_runtime_override.player_data == null:
		var player := PlayerData.new()
		alchemy_runtime_override.setup(player, NightResult.new(), alchemy_runtime_override.day)
		_write("AlchemyRuntime 独立运行：已创建测试用 PlayerData。", Color("#e7c878"))
	if alchemy_runtime_override != null:
		return alchemy_runtime_override.player_data
	var host := get_parent()
	while host != null:
		if host.has_method("get_player_data"):
			var discovered := host.call("get_player_data") as PlayerData
			if discovered != null:
				return discovered
		host = host.get_parent()
	if _fallback_player_data == null:
		_fallback_player_data = PlayerData.new()
		_write("控制台未绑定运行时，已创建独立测试用 PlayerData。", Color("#e7c878"))
	return _fallback_player_data


func _resolve_potion_id(raw_id: String) -> StringName:
	if not raw_id.is_valid_int():
		return StringName(raw_id)
	var index := int(raw_id) - 1
	return POTION_IDS_BY_NUMBER[index] if index >= 0 and index < POTION_IDS_BY_NUMBER.size() else &""


func _alchemy() -> Node:
	if alchemy_runtime_override != null:
		return alchemy_runtime_override
	return night_runtime.alchemy_runtime if night_runtime != null else null


func _day() -> int:
	if day_runtime != null:
		return day_runtime.day
	if day_scene != null:
		return 1
	var alchemy := _alchemy()
	return night_runtime.day if night_runtime != null else (alchemy.day if alchemy != null else 1)


func _set_inventory_count(player: PlayerData, ingredient_id: StringName, count: int) -> void:
	if count <= 0:
		player.inventory.erase(ingredient_id)
	else:
		player.inventory[ingredient_id] = count


func _refresh_alchemy() -> void:
	var alchemy := _alchemy()
	if alchemy != null:
		alchemy.call("_refresh_ui")


func _write(message: String, color: Color) -> void:
	if output == null or message.is_empty():
		return
	output.push_color(color)
	output.add_text(message)
	output.pop()
	output.newline()
	output.scroll_to_line(output.get_line_count())


func _on_command_submitted(command: String) -> void:
	if not command.strip_edges().is_empty():
		_history.append(command)
		_history_index = _history.size()
	execute_command(command)
	command_input.clear()
	command_input.grab_focus()


func _gui_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_UP and not _history.is_empty():
		_history_index = maxi(_history_index - 1, 0)
		command_input.text = _history[_history_index]
		command_input.caret_column = command_input.text.length()
		accept_event()
	elif event.keycode == KEY_DOWN and not _history.is_empty():
		_history_index = mini(_history_index + 1, _history.size())
		command_input.text = "" if _history_index == _history.size() else _history[_history_index]
		command_input.caret_column = command_input.text.length()
		accept_event()
