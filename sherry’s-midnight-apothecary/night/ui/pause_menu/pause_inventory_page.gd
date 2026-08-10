class_name PauseInventoryPage
extends Control

signal loadout_changed
signal potion_selected(potion_id: StringName)
signal potion_equipped(slot_index: int, potion_id: StringName)

const ENTRY_SCENE := preload("res://night/ui/pause_menu/inventory_entry.tscn")

@export var potion_definitions: Array[PotionData] = []
@export var ingredient_definitions: Array[IngredientData] = []
@export var story_item_definitions: Array[StoryItemData] = []
@export var lock_icon: Texture2D
@export var empty_slot_icon: Texture2D
@export var story_item_placeholder: Texture2D

@onready var potion_tab: Button = %PotionTab
@onready var item_tab: Button = %ItemTab
@onready var potion_panel: Control = %PotionPanel
@onready var item_panel: Control = %ItemPanel
@onready var potion_entries: VBoxContainer = %PotionEntries
@onready var potion_empty: Label = %PotionEmpty
@onready var slot_rows: VBoxContainer = %SlotRows
@onready var selection_hint: Label = %SelectionHint
@onready var material_entries: VBoxContainer = %MaterialEntries
@onready var material_empty: Label = %MaterialEmpty
@onready var story_entries: VBoxContainer = %StoryEntries
@onready var story_empty: Label = %StoryEmpty
@onready var detail_icon: TextureRect = %DetailIcon
@onready var detail_name: Label = %DetailName
@onready var detail_count: Label = %DetailCount
@onready var detail_description: Label = %DetailDescription

var player_data: PlayerData
var selected_potion_id: StringName = &""
var _potion_by_id: Dictionary = {}
var _ingredient_by_id: Dictionary = {}
var _story_item_by_id: Dictionary = {}
var _potion_buttons: Dictionary = {}
var _tutorial_active := false
var _tutorial_potion_id: StringName = &""
var _tutorial_phase := ""
var _tutorial_target: CanvasItem
var _tutorial_target_base_modulate := Color.WHITE


func _ready() -> void:
	potion_tab.pressed.connect(show_potions)
	item_tab.pressed.connect(show_items)
	for slot_index in range(slot_rows.get_child_count()):
		var row := slot_rows.get_child(slot_index) as HBoxContainer
		(row.get_node("Main") as Button).pressed.connect(equip_selected_to_slot.bind(slot_index))
		(row.get_node("Unload") as Button).pressed.connect(_unequip_slot.bind(slot_index))
	_build_definition_maps()
	show_potions()
	refresh()


func _process(_delta: float) -> void:
	if not _tutorial_active or not is_instance_valid(_tutorial_target):
		return
	var pulse := (sin(float(Time.get_ticks_msec()) * 0.008) + 1.0) * 0.5
	var glow := Color(1.35, 1.14, 0.52, 1.0)
	_tutorial_target.self_modulate = _tutorial_target_base_modulate.lerp(glow, 0.35 + pulse * 0.45)


func bind_player_data(shared_player_data: PlayerData) -> void:
	player_data = shared_player_data
	selected_potion_id = &""
	if is_node_ready():
		refresh()


func show_potions() -> void:
	potion_panel.show()
	item_panel.hide()
	potion_tab.set_pressed_no_signal(true)
	item_tab.set_pressed_no_signal(false)
	if is_node_ready():
		_refresh_potions()
		_refresh_slots()


func show_items() -> void:
	potion_panel.hide()
	item_panel.show()
	potion_tab.set_pressed_no_signal(false)
	item_tab.set_pressed_no_signal(true)
	if is_node_ready():
		_refresh_items()


func refresh() -> void:
	if not is_node_ready():
		return
	_build_definition_maps()
	_refresh_potions()
	_refresh_slots()
	_refresh_items()


func select_potion(potion_id: StringName) -> void:
	if player_data == null or potion_id == &"" or potion_id == &"black_potion":
		return
	if not player_data.potions.has(potion_id):
		return
	selected_potion_id = potion_id
	for id: Variant in _potion_buttons:
		(_potion_buttons[id] as Button).set_pressed_no_signal(StringName(str(id)) == potion_id)
	_refresh_slots()
	potion_selected.emit(potion_id)
	if _tutorial_active and potion_id == _tutorial_potion_id:
		_tutorial_phase = "slot"
		_refresh_tutorial_display()


func equip_selected_to_slot(slot_index: int) -> void:
	if player_data == null or selected_potion_id == &"":
		return
	var equipped_id := selected_potion_id
	if player_data.move_equip_potion(slot_index, equipped_id):
		selected_potion_id = &""
		loadout_changed.emit()
		_refresh_potions()
		_refresh_slots()
		potion_equipped.emit(slot_index, equipped_id)
		if _tutorial_active and equipped_id == _tutorial_potion_id:
			_tutorial_phase = "complete"
			_refresh_tutorial_display()


func begin_potion_equip_tutorial(potion_id: StringName) -> void:
	if potion_id == &"":
		return
	_tutorial_active = true
	_tutorial_potion_id = potion_id
	_tutorial_phase = "slot" if selected_potion_id == potion_id else "potion"
	show_potions()
	refresh()
	_refresh_tutorial_display()


func end_potion_equip_tutorial() -> void:
	_tutorial_active = false
	_tutorial_potion_id = &""
	_tutorial_phase = ""
	_set_tutorial_target(null)
	_refresh_slots()


func is_potion_equip_tutorial_active() -> bool:
	return _tutorial_active


func get_potion_button(potion_id: StringName) -> Button:
	return _potion_buttons.get(potion_id) as Button


func get_slot_button(slot_index: int) -> Button:
	if slot_index < 0 or slot_index >= slot_rows.get_child_count():
		return null
	return (slot_rows.get_child(slot_index) as Node).get_node("Main") as Button


func get_visible_slot_count() -> int:
	var result := 0
	for row in slot_rows.get_children():
		if (row as Control).visible:
			result += 1
	return result


func _build_definition_maps() -> void:
	_potion_by_id.clear()
	for potion: PotionData in potion_definitions:
		if potion != null:
			_potion_by_id[potion.id] = potion
	_ingredient_by_id.clear()
	for ingredient: IngredientData in ingredient_definitions:
		if ingredient != null:
			_ingredient_by_id[ingredient.id] = ingredient
	_story_item_by_id.clear()
	for story_item: StoryItemData in story_item_definitions:
		if story_item != null:
			_story_item_by_id[story_item.id] = story_item


func _refresh_potions() -> void:
	_clear_container(potion_entries)
	_potion_buttons.clear()
	if player_data == null:
		potion_empty.text = "尚未连接玩家背包"
		potion_empty.show()
		return
	var ids: Array[StringName] = []
	for key: Variant in player_data.potions:
		if player_data.potions[key] is Array and not (player_data.potions[key] as Array).is_empty():
			ids.append(StringName(str(key)))
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return _potion_name(a) < _potion_name(b))
	for potion_id: StringName in ids:
		var potion: PotionData = _potion_by_id.get(potion_id)
		var instances: Array = player_data.potions.get(potion_id, [])
		var total_dose := 0.0
		for instance: Variant in instances:
			if instance is Dictionary:
				total_dose += float((instance as Dictionary).get("remaining_dose", 1.0))
		var button := ENTRY_SCENE.instantiate() as Button
		button.text = "%s\n%d 瓶 · %.2f 剂" % [_potion_name(potion_id), instances.size(), total_dose]
		if potion != null:
			var visual: Dictionary = instances[0] if not instances.is_empty() else {}
			button.icon = PotionSvgRenderer.get_bottle_texture(PotionColorResolver.resolve(potion, visual), 60, minf(total_dose, 1.0), float(visual.get("potency", 1.0)))
		button.disabled = potion_id == &"black_potion"
		button.tooltip_text = "失败药水不可装填" if button.disabled else "选择后点击右页档位进行装填"
		button.pressed.connect(select_potion.bind(potion_id))
		button.set_pressed_no_signal(potion_id == selected_potion_id)
		potion_entries.add_child(button)
		_potion_buttons[potion_id] = button
	potion_empty.text = "当前没有可用药水"
	potion_empty.visible = ids.is_empty()


func _refresh_slots() -> void:
	if not is_node_ready():
		return
	var slot_count := player_data.potion_slot_count if player_data != null else PlayerData.DEFAULT_POTION_SLOT_COUNT
	var display_count := slot_count if slot_count >= PlayerData.MAX_POTION_SLOT_COUNT else slot_count + 1
	for slot_index in range(slot_rows.get_child_count()):
		var row := slot_rows.get_child(slot_index) as HBoxContainer
		row.visible = slot_index < display_count
		if not row.visible:
			continue
		var main := row.get_node("Main") as Button
		var unload := row.get_node("Unload") as Button
		var locked := player_data == null or slot_index >= slot_count
		if locked:
			main.text = "档位 %d  ·  尚未解锁" % (slot_index + 1)
			main.icon = lock_icon
			main.disabled = true
			unload.hide()
			continue
		var equipped_id: StringName = player_data.equipped_potion_ids[slot_index] if slot_index < player_data.equipped_potion_ids.size() else &""
		var total := _total_dose(equipped_id)
		main.text = "档位 %d  ·  %s%s" % [slot_index + 1, "空" if equipped_id == &"" else _potion_name(equipped_id), "（已耗尽）" if equipped_id != &"" and total <= PotionInventoryService.DOSE_EPSILON else ""]
		main.icon = empty_slot_icon if equipped_id == &"" else _potion_icon(equipped_id, total)
		main.disabled = selected_potion_id == &""
		main.tooltip_text = "请先在左页选择药水" if selected_potion_id == &"" else "装填到此档位"
		unload.visible = equipped_id != &""
		unload.disabled = equipped_id == &""
	selection_hint.text = "已选择：%s；请选择目标档位" % _potion_name(selected_potion_id) if selected_potion_id != &"" else "先从左页选择药水，再点击右页档位装填。"
	if _tutorial_active:
		_refresh_tutorial_display()


func _refresh_tutorial_display() -> void:
	if not _tutorial_active:
		return
	match _tutorial_phase:
		"potion":
			selection_hint.text = "教程：用鼠标点击左侧的“%s”。" % _potion_name(_tutorial_potion_id)
			_set_tutorial_target(get_potion_button(_tutorial_potion_id))
		"slot":
			selection_hint.text = "教程：点击右侧任意已解锁档位，将净化药水装入快捷栏。"
			_set_tutorial_target(get_slot_button(_first_unlocked_slot()))
		"complete":
			selection_hint.text = "装配完成！点击右侧“返回”书签继续。"
			_set_tutorial_target(null)


func _first_unlocked_slot() -> int:
	if player_data == null:
		return 0
	for slot_index in range(player_data.potion_slot_count):
		if slot_index >= player_data.equipped_potion_ids.size() or player_data.equipped_potion_ids[slot_index] == &"":
			return slot_index
	return clampi(player_data.selected_potion_slot, 0, player_data.potion_slot_count - 1)


func _set_tutorial_target(target: CanvasItem) -> void:
	if is_instance_valid(_tutorial_target):
		_tutorial_target.self_modulate = _tutorial_target_base_modulate
	_tutorial_target = target
	if is_instance_valid(_tutorial_target):
		_tutorial_target_base_modulate = _tutorial_target.self_modulate


func _refresh_items() -> void:
	_clear_container(material_entries)
	_clear_container(story_entries)
	if player_data == null:
		material_empty.text = "尚未连接玩家背包"
		story_empty.text = "尚未连接玩家背包"
		material_empty.show()
		story_empty.show()
		_show_detail(null, "选择左页条目查看详情", 0, "")
		return
	var material_ids := _sorted_count_ids(player_data.inventory, _ingredient_by_id)
	for item_id: StringName in material_ids:
		var data: IngredientData = _ingredient_by_id.get(item_id)
		var item_name := data.display_name if data != null else str(item_id)
		var description := data.description if data != null and not data.description.is_empty() else "尚无详细说明。"
		var icon := data.icon if data != null else null
		_add_item_entry(material_entries, item_id, item_name, int(player_data.inventory[item_id]), description, icon)
	material_empty.text = "当前没有炼药材料"
	material_empty.visible = material_ids.is_empty()
	var story_ids := _sorted_count_ids(player_data.story_items, _story_item_by_id)
	for item_id: StringName in story_ids:
		var data: StoryItemData = _story_item_by_id.get(item_id)
		var item_name := data.display_name if data != null else str(item_id)
		var description := data.description if data != null and not data.description.is_empty() else "这件剧情道具尚未录入说明。"
		var icon := data.icon if data != null and data.icon != null else story_item_placeholder
		_add_item_entry(story_entries, item_id, item_name, int(player_data.story_items[item_id]), description, icon)
	story_empty.text = "当前没有剧情道具"
	story_empty.visible = story_ids.is_empty()
	_show_detail(story_item_placeholder, "选择左页条目查看详情", 0, "")


func _add_item_entry(container: VBoxContainer, item_id: StringName, item_name: String, count: int, description: String, icon: Texture2D) -> void:
	var button := ENTRY_SCENE.instantiate() as Button
	button.text = "%s  ×%d" % [item_name, count]
	button.icon = icon
	button.tooltip_text = str(item_id)
	button.pressed.connect(_show_detail.bind(icon, item_name, count, description))
	container.add_child(button)


func _show_detail(icon: Texture2D, item_name: String, count: int, description: String) -> void:
	detail_icon.texture = icon
	detail_name.text = item_name
	detail_count.text = "持有数量：%d" % count if count > 0 else ""
	detail_description.text = description


func _unequip_slot(slot_index: int) -> void:
	if player_data == null:
		return
	player_data.unequip_potion(slot_index)
	loadout_changed.emit()
	_refresh_slots()


func _potion_name(potion_id: StringName) -> String:
	var potion: PotionData = _potion_by_id.get(potion_id)
	return potion.display_name if potion != null else str(potion_id)


func _total_dose(potion_id: StringName) -> float:
	if player_data == null or potion_id == &"":
		return 0.0
	var total := 0.0
	for instance: Variant in player_data.potions.get(potion_id, []):
		if instance is Dictionary:
			total += float((instance as Dictionary).get("remaining_dose", 1.0))
	return total


func _potion_icon(potion_id: StringName, total_dose: float) -> Texture2D:
	var potion: PotionData = _potion_by_id.get(potion_id)
	if potion == null:
		return empty_slot_icon
	var instances: Array = player_data.potions.get(potion_id, [])
	var visual: Dictionary = instances[0] if not instances.is_empty() else {"quality": 1.0, "potency": 1.0, "mixed_x": potion.spectrum_center_x}
	return PotionSvgRenderer.get_bottle_texture(PotionColorResolver.resolve(potion, visual), 54, minf(total_dose, 1.0), float(visual.get("potency", 1.0)))


func _sorted_count_ids(counts: Dictionary, definitions: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	for key: Variant in counts:
		if int(counts[key]) > 0:
			result.append(StringName(str(key)))
	result.sort_custom(func(a: StringName, b: StringName) -> bool:
		var data_a: Resource = definitions.get(a)
		var data_b: Resource = definitions.get(b)
		var name_a := str(data_a.get("display_name")) if data_a != null else str(a)
		var name_b := str(data_b.get("display_name")) if data_b != null else str(b)
		return name_a < name_b
	)
	return result


func _clear_container(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
