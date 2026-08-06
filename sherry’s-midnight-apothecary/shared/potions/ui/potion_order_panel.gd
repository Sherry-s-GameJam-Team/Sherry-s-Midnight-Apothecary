class_name PotionOrderPanel
extends PanelContainer

signal order_changed(potion_id: StringName, ordered_uids: Array[String])

var inventory_service: PotionInventoryService
var potion_id: StringName
var _rows: VBoxContainer
var _title: Label


func _ready() -> void:
	custom_minimum_size = Vector2(390, 300)
	var root := VBoxContainer.new()
	add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.pressed.connect(hide)
	header.add_child(close_button)
	var hint := Label.new()
	hint.text = "越靠上越先消耗；调整会立即保存。"
	root.add_child(hint)
	_rows = VBoxContainer.new()
	root.add_child(_rows)
	hide()


func open_for(service: PotionInventoryService, selected_potion_id: StringName, display_name: String) -> void:
	inventory_service = service
	potion_id = selected_potion_id
	_title.text = "%s · 投掷顺序" % display_name
	_rebuild()
	show()


func _rebuild() -> void:
	if _rows == null or inventory_service == null:
		return
	for child in _rows.get_children():
		child.queue_free()
	var instances := inventory_service.get_instances(potion_id)
	var order: Array[String] = []
	if inventory_service.player_data != null:
		for uid: Variant in inventory_service.player_data.potion_throw_orders.get(potion_id, []):
			order.append(str(uid))
	instances.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return order.find(str(a.get("instance_uid", ""))) < order.find(str(b.get("instance_uid", ""))))
	for index in range(instances.size()):
		var instance: Dictionary = instances[index]
		var row := HBoxContainer.new()
		_rows.add_child(row)
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text = "%d. 品质 %.2f  剩余 %.2f  %s" % [index + 1, float(instance.get("quality", 1.0)), float(instance.get("remaining_dose", 1.0)), str(instance.get("instance_uid", ""))]
		row.add_child(label)
		var up := Button.new()
		up.text = "↑"
		up.disabled = index == 0
		up.pressed.connect(_move_uid.bind(str(instance.get("instance_uid", "")), -1))
		row.add_child(up)
		var down := Button.new()
		down.text = "↓"
		down.disabled = index == instances.size() - 1
		down.pressed.connect(_move_uid.bind(str(instance.get("instance_uid", "")), 1))
		row.add_child(down)


func _move_uid(uid: String, direction: int) -> void:
	if inventory_service == null or inventory_service.player_data == null:
		return
	var order: Array[String] = []
	for value: Variant in inventory_service.player_data.potion_throw_orders.get(potion_id, []):
		order.append(str(value))
	var from := order.find(uid)
	var to := clampi(from + direction, 0, order.size() - 1)
	if from < 0 or from == to:
		return
	var swap := order[to]
	order[to] = order[from]
	order[from] = swap
	inventory_service.set_throw_order(potion_id, order)
	order_changed.emit(potion_id, order)
	_rebuild()

