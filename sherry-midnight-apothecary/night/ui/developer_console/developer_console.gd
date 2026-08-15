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

var night_runtime: NightRuntime
var day_runtime: Node
var day_scene: Node
var alchemy_runtime_override: AlchemyRuntime
var _previous_tree_paused := false
var _history: Array[String] = []
var _history_index := 0
var _welcomed := false
var _toggle_key_was_down := false
var _fallback_player_data: PlayerData

const FALLBACK_INGREDIENTS: Array[IngredientData] = [
	preload("res://shared/definitions/data/ingredients/herdsmans_loaf_bush.tres"),
	preload("res://shared/definitions/data/ingredients/stardust_puffy_lion.tres"),
	preload("res://shared/definitions/data/ingredients/grail_lily.tres"),
	preload("res://shared/definitions/data/ingredients/dew_flask_herb.tres"),
	preload("res://shared/definitions/data/ingredients/old_mans_noose.tres"),
	preload("res://shared/definitions/data/ingredients/praise_star_maple.tres"),
	preload("res://shared/definitions/data/ingredients/amber_root.tres"),
	preload("res://shared/definitions/data/ingredients/blue_bell.tres"),
	preload("res://shared/definitions/data/ingredients/mist_leaf.tres"),
	preload("res://shared/definitions/data/ingredients/moon_mint.tres"),
	preload("res://shared/definitions/data/ingredients/red_berry.tres"),
	preload("res://shared/definitions/data/ingredients/star_lavender.tres"),
	preload("res://shared/definitions/data/ingredients/sun_daisy.tres"),
	preload("res://shared/definitions/data/ingredients/violet_thistle.tres"),
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


func setup(runtime: NightRuntime) -> void:
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


func setup_alchemy(runtime: AlchemyRuntime) -> void:
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
	var app_root := get_node_or_null("/root/AppRoot") as AppRoot
	if app_root == null or app_root.game_flow == null:
		return "错误：GameFlow 尚未初始化。"
	var target_mode := GameFlow.Mode.DAY if parts[0].to_lower() == "day" else GameFlow.Mode.NIGHT
	if app_root.game_flow.current_mode == target_mode:
		return "mode = %s" % parts[0].to_lower()
	if not app_root.game_flow.debug_switch_mode(target_mode):
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
			if plant_number < 1 or plant_number > FALLBACK_INGREDIENTS.size():
				return "错误：植物序号超出范围。"
			ingredient_id = FALLBACK_INGREDIENTS[plant_number - 1].id
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


func _scene_command(parts: PackedStringArray) -> String:
	if day_runtime == null and day_scene == null:
		return "错误：场景切换仅可在日间模式使用。"
	if parts.size() != 2:
		return "错误：用法 scene <town|home|raintree|lake|grassland>"
	var requested := parts[1].to_lower()
	var level_id := ""
	match requested:
		"town", "market":
			level_id = "market"
		"home":
			level_id = "home"
		"raintree", "rain_tree", "forest":
			level_id = "forest"
		"lake":
			level_id = "lake"
		"grass", "grassland":
			level_id = "grassland"
		_:
			return "错误：未知场景。可用：town、home、raintree、lake、grassland。"
	if day_runtime != null:
		if not day_runtime.switch_to_level(level_id):
			return "错误：无法切换到场景 %s。" % requested
		return "scene = %s" % day_runtime.current_level.display_name
	var scene_path := {
		"market": "res://day/levels/market/town/town.tscn",
		"home": "res://day/levels/home/home.tscn",
		"forest": "res://day/art/raintree/raintree.tscn",
		"lake": "res://day/art/lake/lake.tscn",
		"grassland": "res://day/levels/grassland/grass.tscn",
	}.get(level_id, "") as String
	if scene_path.is_empty() or get_tree().change_scene_to_file(scene_path) != OK:
		return "错误：无法切换到场景 %s。" % requested
	return "scene = %s" % requested


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


func _help_text() -> String:
	return """Day scene commands:
	  scene <town|home|raintree|lake|grassland>
  title
  to normal
  to corrupted

Other commands:
  day, night, status, get, set, add, give, take, potion, temp, clear, close"""
	return """可用命令：
  status
  get <参数>
  set <参数> <数值>
  add <参数> <增量>
  give <植物序号|ingredient_id> [数量]
  take <植物序号|ingredient_id> [数量]
  potion <potion_id> [数量] [品质]
  temp <0–100>
  clear / close
参数：money、debt、health、max_health、temp、
      inventory.<id>、potions.<id>"""


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


func _alchemy() -> AlchemyRuntime:
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
