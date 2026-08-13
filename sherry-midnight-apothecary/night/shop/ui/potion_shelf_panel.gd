class_name PotionShelfPanel
extends PanelContainer

signal potion_selected(potion_id: StringName, uid: String)

const ITEM_SCENE := preload("res://night/shop/ui/potion_shelf_item.tscn")

@onready var shelf: VBoxContainer = $Sprite2D/Margin/VBox/Scroll/Shelf
@onready var selection_label: Label = $Sprite2D/Margin/VBox/SelectionLabel


func clear_items() -> void:
	if shelf == null:
		return
	for child in shelf.get_children():
		shelf.remove_child(child)
		child.queue_free()


func add_potion(potion: PotionData, instance: Dictionary, price: int, selected: bool) -> void:
	if shelf == null:
		return
	var item := ITEM_SCENE.instantiate() as Button
	shelf.add_child(item)
	item.show_potion(potion, instance, price)
	item.button_pressed = selected
	item.pressed.connect(func() -> void: potion_selected.emit(potion.id, str(instance.get("instance_uid", ""))))


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
