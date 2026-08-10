class_name PotionHotbar
extends CanvasLayer

signal slot_selected(slot_index: int)

@export_range(0.03, 0.5, 0.01) var refresh_interval := 0.1

var inventory_service: PotionInventoryService
var potion_definitions: Dictionary = {}
var dose_per_throw := 0.0
var _slot_buttons: Array[Button] = []
var _slot_views: Array[PotionHotbarSlot] = []
@onready var _slots: VBoxContainer = %Slots
@onready var _order_panel: PotionOrderPanel = %OrderPanel
var _refresh_accumulator := 0.0


func _ready() -> void:
	_slot_views.assign([
		%Slot1, %Slot2, %Slot3, %Slot4,
		%Slot5, %Slot6, %Slot7, %Slot8,
	])
	for slot_index in range(_slot_views.size()):
		var slot_view := _slot_views[slot_index]
		slot_view.set_slot_number(slot_index + 1)
		slot_view.button.pressed.connect(_on_slot_pressed.bind(slot_index))
	_order_panel.hide()


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
	if _refresh_accumulator >= refresh_interval:
		_refresh_accumulator = 0.0
		_refresh_slots()


func _rebuild_slots() -> void:
	if _slots == null or inventory_service == null or inventory_service.player_data == null:
		return
	_slot_buttons.clear()
	for slot_index in range(_slot_views.size()):
		var visible_slot := slot_index < inventory_service.player_data.potion_slot_count
		_slot_views[slot_index].visible = visible_slot
		if visible_slot:
			_slot_buttons.append(_slot_views[slot_index].button)
	_refresh_slots()


func _refresh_slots() -> void:
	if inventory_service == null or inventory_service.player_data == null:
		return
	var player_data := inventory_service.player_data
	if player_data.potion_slot_count > _slot_views.size():
		push_warning("PotionHotbar only has %d editor-defined slots." % _slot_views.size())
		return
	if _slot_buttons.size() != player_data.potion_slot_count:
		_rebuild_slots()
		return
	for index in range(player_data.potion_slot_count):
		var potion_id: StringName = player_data.equipped_potion_ids[index] if index < player_data.equipped_potion_ids.size() else &""
		var equipped := potion_id != &"" and potion_id != &"black_potion"
		var total := inventory_service.get_total_dose(potion_id) if equipped else 0.0
		var next := inventory_service.get_next_instance(potion_id) if equipped else {}
		var potion: PotionData = potion_definitions.get(potion_id)
		var label := potion.display_name if potion != null else ("空槽位" if not equipped else str(potion_id))
		var insufficient := equipped and total + PotionInventoryService.DOSE_EPSILON < dose_per_throw
		var current_bottle_ratio := clampf(float(next.get("remaining_dose", 0.0)), 0.0, 1.0)
		var visual_instance: Dictionary = next if not next.is_empty() else {
			"quality": 1.0,
			"potency": 1.0,
			"mixed_x": potion.spectrum_center_x if potion != null else 0.0,
		}
		var color := PotionColorResolver.resolve(potion, visual_instance) if potion != null else Color(0.42, 0.46, 0.54)
		var texture := PotionSvgRenderer.get_bottle_texture(
			color,
			64,
			current_bottle_ratio,
			float(visual_instance.get("potency", 0.65 if not equipped else 1.0))
		)
		var tooltip := "%d · %s\n当前瓶 %.0f%% · 总剂量 %.2f" % [index + 1, label, current_bottle_ratio * 100.0, total]
		if insufficient:
			tooltip += "\n剂量不足"
		_slot_views[index].set_display(
			texture,
			current_bottle_ratio,
			color,
			index == player_data.selected_potion_slot,
			equipped,
			insufficient,
			tooltip
		)


func _on_slot_pressed(slot_index: int) -> void:
	if inventory_service == null or inventory_service.player_data == null:
		return
	var player_data := inventory_service.player_data
	if slot_index < 0 or slot_index >= player_data.potion_slot_count:
		return
	if player_data.selected_potion_slot == slot_index:
		var potion_id: StringName = (
			player_data.equipped_potion_ids[slot_index]
			if slot_index < player_data.equipped_potion_ids.size()
			else &""
		)
		var potion: PotionData = potion_definitions.get(potion_id)
		if potion != null:
			_order_panel.open_for(inventory_service, potion_id, potion.display_name)
		return
	player_data.select_potion_slot(slot_index)
	_order_panel.hide()
	slot_selected.emit(slot_index)
	_refresh_slots()
