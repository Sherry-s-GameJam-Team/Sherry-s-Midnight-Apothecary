class_name PotionHotbar
extends CanvasLayer

signal slot_selected(slot_index: int)

var inventory_service: PotionInventoryService
var potion_definitions: Dictionary = {}
var dose_per_throw := 0.0
var _slot_buttons: Array[Button] = []
var _slots: HBoxContainer
var _order_panel: PotionOrderPanel
var _refresh_accumulator := 0.0


func _ready() -> void:
	layer = 90
	var full := Control.new()
	full.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	full.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(full)
	_slots = HBoxContainer.new()
	_slots.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_slots.position = Vector2(-270, -112)
	_slots.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_slots.add_theme_constant_override("separation", 10)
	full.add_child(_slots)
	_order_panel = preload("res://shared/potions/ui/potion_order_panel.tscn").instantiate()
	_order_panel.set_anchors_preset(Control.PRESET_CENTER)
	_order_panel.position = Vector2(-195, -150)
	full.add_child(_order_panel)


func setup(service: PotionInventoryService, definitions: Dictionary, configured_dose_per_throw: float) -> void:
	inventory_service = service
	potion_definitions = definitions
	dose_per_throw = configured_dose_per_throw
	_rebuild_slots()


func is_detail_open() -> bool:
	return _order_panel != null and _order_panel.visible


func close_detail() -> void:
	if _order_panel != null:
		_order_panel.hide()


func _process(delta: float) -> void:
	_refresh_accumulator += delta
	if _refresh_accumulator >= 0.2:
		_refresh_accumulator = 0.0
		_refresh_slots()


func _rebuild_slots() -> void:
	if _slots == null or inventory_service == null or inventory_service.player_data == null:
		return
	for child in _slots.get_children():
		child.queue_free()
	_slot_buttons.clear()
	for slot_index in range(inventory_service.player_data.potion_slot_count):
		var button := Button.new()
		button.custom_minimum_size = Vector2(128, 92)
		button.expand_icon = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_on_slot_pressed.bind(slot_index))
		_slots.add_child(button)
		_slot_buttons.append(button)
	_refresh_slots()


func _refresh_slots() -> void:
	if inventory_service == null or inventory_service.player_data == null:
		return
	if _slot_buttons.size() != inventory_service.player_data.potion_slot_count:
		_rebuild_slots()
		return
	for index in range(_slot_buttons.size()):
		var potion_id: StringName = inventory_service.player_data.equipped_potion_ids[index] if index < inventory_service.player_data.equipped_potion_ids.size() else &""
		var total := inventory_service.get_total_dose(potion_id) if potion_id != &"" else 0.0
		var next := inventory_service.get_next_instance(potion_id) if potion_id != &"" else {}
		var potion: PotionData = potion_definitions.get(potion_id)
		var label := potion.display_name if potion != null else ("空槽位" if potion_id == &"" else str(potion_id))
		var insufficient := total + PotionInventoryService.DOSE_EPSILON < dose_per_throw
		_slot_buttons[index].text = "%d  %s%s\n剂量 %.2f  下瓶 %.2f" % [index + 1, label, " [不足]" if insufficient else "", total, float(next.get("quality", 0.0))]
		_slot_buttons[index].disabled = potion_id == &"" or potion_id == &"black_potion"
		_slot_buttons[index].button_pressed = index == inventory_service.player_data.selected_potion_slot
		_slot_buttons[index].modulate = Color(1.18, 1.12, 0.72) if index == inventory_service.player_data.selected_potion_slot else (Color(0.62, 0.62, 0.62) if insufficient else Color.WHITE)
		if potion != null:
			var visual_instance := next if not next.is_empty() else {"quality": 1.0, "potency": 1.0, "mixed_x": potion.spectrum_center_x}
			var color := PotionColorResolver.resolve(potion, visual_instance)
			_slot_buttons[index].icon = PotionSvgRenderer.get_bottle_texture(color, 64, minf(total, 1.0), float(visual_instance.get("potency", 1.0)))


func _on_slot_pressed(slot_index: int) -> void:
	if inventory_service == null or inventory_service.player_data == null:
		return
	if inventory_service.player_data.selected_potion_slot == slot_index:
		var potion_id: StringName = inventory_service.player_data.equipped_potion_ids[slot_index]
		var potion: PotionData = potion_definitions.get(potion_id)
		if potion != null:
			_order_panel.open_for(inventory_service, potion_id, potion.display_name)
		return
	inventory_service.player_data.select_potion_slot(slot_index)
	_order_panel.hide()
	slot_selected.emit(slot_index)
	_refresh_slots()
