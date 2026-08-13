class_name PotionShelfPanel
extends PanelContainer

signal potion_selected(potion_id: StringName, uid: String)

const ITEM_SCENE := preload("res://night/shop/ui/potion_shelf_item.tscn")

@onready var shelf: VBoxContainer = %Shelf
@onready var selection_label: Label = %SelectionLabel


func clear_items() -> void:
	for child in shelf.get_children():
		shelf.remove_child(child)
		child.queue_free()


func add_potion(potion: PotionData, instance: Dictionary, price: int, selected: bool) -> void:
	var item := ITEM_SCENE.instantiate() as Button
	item.show_potion(potion, instance, price)
	item.button_pressed = selected
	item.pressed.connect(func() -> void: potion_selected.emit(potion.id, str(instance.get("instance_uid", ""))))
	shelf.add_child(item)


func show_empty_message(message: String) -> void:
	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shelf.add_child(label)


func set_selection_text(text: String) -> void:
	selection_label.text = text
