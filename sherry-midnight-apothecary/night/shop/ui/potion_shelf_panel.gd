class_name PotionShelfPanel
extends PanelContainer

signal potion_selected(potion_id: StringName, uid: String)
signal potion_hovered(potion: PotionData, instance: Dictionary, price: int)
signal potion_unhovered

const ITEM_SCENE := preload("res://night/shop/ui/potion_shelf_item.tscn")

@onready var shelf: Control = $Sprite2D/Margin/VBox/ShelfCanvas
@onready var selection_label: Label = $Sprite2D/Margin/VBox/SelectionLabel


func clear_items() -> void:
	if shelf == null:
		return
	for child in shelf.get_children():
		if child.name.begins_with("DisplaySlot"):
			for slot_child in child.get_children():
				slot_child.queue_free()
		else:
			shelf.remove_child(child)
			child.queue_free()


func add_potion(potion: PotionData, instance: Dictionary, price: int, selected: bool) -> void:
	if shelf == null:
		return
	var item := ITEM_SCENE.instantiate() as Button
	var slot := shelf.get_node_or_null("DisplaySlot%d" % (_displayed_count() + 1)) as Control
	if slot != null:
		slot.add_child(item)
		item.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		shelf.add_child(item)
		item.position = Vector2(18 + _displayed_count() * 92, 24)
	item.show_potion(potion, instance, price)
	item.button_pressed = selected
	item.potion_hovered.connect(func(next_potion: PotionData, next_instance: Dictionary, next_price: int) -> void: potion_hovered.emit(next_potion, next_instance, next_price))
	item.potion_unhovered.connect(func() -> void: potion_unhovered.emit())
	item.pressed.connect(func() -> void: potion_selected.emit(potion.id, str(instance.get("instance_uid", ""))))


func _displayed_count() -> int:
	var count := 0
	for child in shelf.get_children():
		if child.name.begins_with("DisplaySlot") and child.get_child_count() > 0:
			count += 1
	return count


func show_empty_message(message: String) -> void:
	if shelf == null:
		return
	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shelf.add_child(label)


func set_selection_text(text: String) -> void:
	if selection_label != null:
		selection_label.text = text
