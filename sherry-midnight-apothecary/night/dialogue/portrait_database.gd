class_name DialoguePortraitDatabase
extends RefCounted

## Central registry for character portraits, expressions, and slot positioning metadata.
## Automatically maps NPC identities, main characters, and custom registered portraits.

const NPC_BASE_PATH := "res://characters/npcs/"

const NPC_DEFINITIONS: Array[Dictionary] = [
	{"id": "01_young_villager", "name": "年轻村民", "folder": "01_young_villager"},
	{"id": "02_herbalist", "name": "采药妇", "folder": "02_herbalist"},
	{"id": "03_blacksmith", "name": "铁匠", "folder": "03_blacksmith"},
	{"id": "04_scholar", "name": "女学者", "folder": "04_scholar"},
	{"id": "05_monk", "name": "修士", "folder": "05_monk"},
	{"id": "06_town_guard", "name": "城镇守卫", "folder": "06_town_guard"},
	{"id": "07_ranger", "name": "游侠", "folder": "07_ranger"},
	{"id": "08_innkeeper", "name": "女店主", "folder": "08_innkeeper"},
	{"id": "09_traveling_merchant", "name": "旅行商人", "folder": "09_traveling_merchant"},
	{"id": "10_village_boy", "name": "村童", "folder": "10_village_boy"},
	{"id": "11_elder", "name": "老妇人", "folder": "11_elder"},
	{"id": "12_baker", "name": "面包师", "folder": "12_baker"},
	{"id": "13_water_carrier", "name": "提水女工", "folder": "13_water_carrier"},
	{"id": "14_scribe", "name": "书记官", "folder": "14_scribe"},
	{"id": "15_nobleman", "name": "贵族", "folder": "15_nobleman"},
	{"id": "16_bard", "name": "吟游诗人", "folder": "16_bard"},
	{"id": "17_nun", "name": "修女", "folder": "17_nun"},
	{"id": "18_hooded_stranger", "name": "兜帽陌生人", "folder": "18_hooded_stranger"},
]

# In-memory registry for runtime additions or custom expression overrides
# Structure: { character_key: { expression_key: Texture2D or texture_path } }
static var _custom_registry: Dictionary = {}
static var _texture_cache: Dictionary = {}


## Resolves a Texture2D for the given character name/id and expression.
static func get_portrait_texture(character_name: String, expression: String = "default") -> Texture2D:
	var clean_char := character_name.strip_edges()
	var clean_expr := expression.strip_edges().to_lower()
	if clean_expr.is_empty():
		clean_expr = "default"

	var cache_key := "%s:%s" % [clean_char.to_lower(), clean_expr]
	if _texture_cache.has(cache_key):
		return _texture_cache[cache_key]

	var texture: Texture2D = null

	# 1. Check custom registry first
	var char_lookup := clean_char.to_lower()
	if _custom_registry.has(char_lookup) and _custom_registry[char_lookup].has(clean_expr):
		var target: Variant = _custom_registry[char_lookup][clean_expr]
		texture = _load_texture(target)

	# 2. Check direct file path if provided
	if texture == null and (clean_char.begins_with("res://") or clean_char.ends_with(".png") or clean_char.ends_with(".jpg")):
		texture = _load_texture(clean_char)

	# 3. Check built-in NPCs
	if texture == null:
		texture = _resolve_npc_texture(clean_char, clean_expr)

	# 4. Check main characters (Sherry, Luca, Mew)
	if texture == null:
		texture = _resolve_main_character_texture(clean_char, clean_expr)

	if texture != null:
		_texture_cache[cache_key] = texture

	return texture


## Registers or overrides a character portrait expression.
static func register_portrait(character_name: String, expression: String, texture_or_path: Variant) -> void:
	var char_key := character_name.strip_edges().to_lower()
	var expr_key := expression.strip_edges().to_lower()
	if not _custom_registry.has(char_key):
		_custom_registry[char_key] = {}
	_custom_registry[char_key][expr_key] = texture_or_path
	_texture_cache.erase("%s:%s" % [char_key, expr_key])


## Clears custom runtime registrations and texture cache.
static func clear_cache() -> void:
	_custom_registry.clear()
	_texture_cache.clear()


## Resolves standard slot name ("left", "center", "right") from various alias strings.
static func normalize_slot(slot_name: String) -> String:
	var s := slot_name.strip_edges().to_lower()
	match s:
		"left", "l", "左", "左侧":
			return "left"
		"right", "r", "右", "右侧":
			return "right"
		"center", "c", "mid", "middle", "中", "中间", "中央":
			return "center"
		_:
			return "center"


## Returns default placement slot for a given character.
static func get_default_slot_for_character(character_name: String) -> String:
	var c := character_name.strip_edges().to_lower()
	if c in ["sherry", "雪莉"]:
		return "right"
	return "left"


static func _resolve_npc_texture(character_name: String, _expression: String) -> Texture2D:
	var char_lower := character_name.to_lower()
	for def in NPC_DEFINITIONS:
		var matches_id: bool = (char_lower == def.id.to_lower()) or (char_lower == def.id.substr(3).to_lower())
		var matches_name: bool = (character_name == def.name) or (char_lower == def.name.to_lower())
		var matches_folder: bool = (char_lower == def.folder.to_lower())
		if matches_id or matches_name or matches_folder:
			var bust_path := "%s%s/frontal_bust.png" % [NPC_BASE_PATH, def.folder]
			var texture := _load_texture(bust_path)
			if texture != null:
				return texture
			var cutout_path := "%s%s/source_cutout.png" % [NPC_BASE_PATH, def.folder]
			return _load_texture(cutout_path)
	return null


static func _resolve_main_character_texture(character_name: String, _expression: String) -> Texture2D:
	var c := character_name.to_lower()
	if c in ["mew", "喵呜", "喵斯", "mews", "卡琳娜", "卡琳娜·喵斯", "炉边烤鱼的少女"]:
		var mew_tex := _load_texture("res://characters/mew/mew_stand.png")
		if mew_tex != null:
			return mew_tex
		return _load_texture("res://characters/mew/frames/idle_000.png")
	elif c in ["sherry", "雪莉"]:
		var stand := _load_texture("res://characters/sherry/sherry_stand.png")
		if stand != null:
			return stand
		return _load_texture("res://characters/sherry/frames/01_idle/idle_001.png")
	elif c in ["luca", "卢卡"]:
		return _load_texture("res://characters/luca/luca_stand.png")
	return null


static func _load_texture(target: Variant) -> Texture2D:
	if target is Texture2D:
		return target
	if target is String and ResourceLoader.exists(target):
		return load(target) as Texture2D
	return null
