class_name BusinessPlaceholder
extends Control

signal request_return

const POTIONS: Array[PotionData] = [
	preload("res://shared/definitions/data/potions/red_potion.tres"),
	preload("res://shared/definitions/data/potions/orange_potion.tres"),
	preload("res://shared/definitions/data/potions/yellow_potion.tres"),
	preload("res://shared/definitions/data/potions/green_potion.tres"),
	preload("res://shared/definitions/data/potions/cyan_potion.tres"),
	preload("res://shared/definitions/data/potions/blue_potion.tres"),
	preload("res://shared/definitions/data/potions/purple_potion.tres"),
	preload("res://shared/definitions/data/potions/purification_potion.tres"),
]
const CUSTOMERS := [
	{"name": "年轻村民", "identity": "夜归村民", "request": "最近总觉得没精神，能给我一瓶温和些的药水吗？", "potion": &"green_potion", "portrait": preload("res://characters/npcs/01_young_villager/frontal_bust.png"), "modifier": 1.0},
	{"name": "采药妇", "identity": "山路采药人", "request": "山里的雾越来越浓，我想备一瓶能护身的药水。", "potion": &"cyan_potion", "portrait": preload("res://characters/npcs/02_herbalist/frontal_bust.png"), "modifier": 1.05},
	{"name": "铁匠", "identity": "炉火铁匠", "request": "明天要赶一批重活，给我来一瓶够劲的。", "potion": &"red_potion", "portrait": preload("res://characters/npcs/03_blacksmith/frontal_bust.png"), "modifier": 1.1},
]

@onready var night_label: Label = %NightLabel
@onready var progress_label: Label = %ProgressLabel
@onready var economy_label: Label = %EconomyLabel
@onready var request_card: CustomerRequestCard = %CustomerRequestCard
@onready var customer_portrait: TextureRect = %CustomerPortrait
@onready var patience_bar: ProgressBar = %PatienceBar
@onready var shelf: VBoxContainer = %Shelf
@onready var selection_label: Label = %SelectionLabel
@onready var sell_button: Button = %SellButton
@onready var reject_button: Button = %RejectButton
@onready var end_button: Button = %EndButton
@onready var feedback: SaleFeedback = %SaleFeedback
@onready var confirm_dialog: ConfirmationDialog = %ConfirmDialog

var player_data: PlayerData
var night_result: NightResult
var day := 1
var current_index := 0
var selected_potion_id: StringName = &""
var selected_uid := ""
var transition_lock := false
var session_earnings := 0
var _potion_by_id: Dictionary = {}


func _ready() -> void:
	for potion: PotionData in POTIONS:
		_potion_by_id[potion.id] = potion
	_refresh()


func setup(shared_player_data: PlayerData, shared_night_result: NightResult, current_day: int) -> void:
	player_data = shared_player_data
	night_result = shared_night_result
	day = maxi(current_day, 1)
	current_index = 0
	selected_potion_id = &""
	selected_uid = ""
	session_earnings = 0
	if is_node_ready():
		_refresh()


func refresh_from_runtime() -> void:
	_refresh()


func current_customer() -> Dictionary:
	return CUSTOMERS[current_index] if current_index >= 0 and current_index < CUSTOMERS.size() else {}


func _refresh() -> void:
	if not is_node_ready():
		return
	night_label.text = "第 %02d 夜 · 营业白模" % day
	progress_label.text = "顾客 %d / %d" % [mini(current_index + 1, CUSTOMERS.size()), CUSTOMERS.size()]
	var wallet := player_data.money if player_data != null else 0
	var debt := player_data.debt if player_data != null else 30000
	economy_label.text = "待结算 +%d曜 · 持有 %d曜 · 债务 %d曜" % [night_result.earned_money if night_result != null else 0, wallet, debt]
	var customer := current_customer()
	var complete := customer.is_empty()
	if complete:
		request_card.visible = false
		customer_portrait.texture = null
		selection_label.text = "今晚的顾客已经全部接待完毕。"
		sell_button.disabled = true
		reject_button.disabled = true
	else:
		request_card.visible = true
		request_card.show_customer(customer, _potion_name(customer.potion))
		customer_portrait.texture = customer.portrait
		patience_bar.value = 80.0
		reject_button.disabled = transition_lock
	_refresh_shelf()
	_update_sale_button()


func _refresh_shelf() -> void:
	for child in shelf.get_children():
		shelf.remove_child(child)
		child.queue_free()
	selected_potion_id = &"" if _find_instance(selected_potion_id, selected_uid).is_empty() else selected_potion_id
	if player_data == null:
		_add_shelf_message("暂无药水。请先到制药台制作。")
		return
	var count := 0
	for potion: PotionData in POTIONS:
		for item: Variant in player_data.potions.get(potion.id, []):
			if item is not Dictionary:
				continue
			var instance := item as Dictionary
			var uid := str(instance.get("instance_uid", ""))
			if uid.is_empty() or float(instance.get("remaining_dose", 1.0)) <= 0.0001 or _is_sold(uid):
				continue
			count += 1
			var button := Button.new()
			var price := _sale_value(potion, instance, float(current_customer().get("modifier", 1.0)))
			button.text = "%s\n品质 %.0f%% · 剩余 %.2f · %d曜" % [potion.display_name, float(instance.get("quality", 1.0)) * 100.0, float(instance.get("remaining_dose", 1.0)), price]
			button.custom_minimum_size.y = 66.0
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.toggle_mode = true
			button.button_pressed = selected_uid == uid
			button.pressed.connect(_on_potion_chosen.bind(potion.id, uid))
			shelf.add_child(button)
	if count == 0:
		_add_shelf_message("货架为空，或本夜的药水已经售出。")


func _add_shelf_message(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shelf.add_child(label)


func _on_potion_chosen(potion_id: StringName, uid: String) -> void:
	if transition_lock or _is_sold(uid):
		return
	selected_potion_id = potion_id
	selected_uid = uid
	var potion: PotionData = _potion_by_id.get(potion_id)
	selection_label.text = "已选择：%s · 报价 %d曜" % [potion.display_name if potion != null else str(potion_id), _sale_value(potion, _find_instance(potion_id, uid), float(current_customer().get("modifier", 1.0)))]
	_update_sale_button()


func _update_sale_button() -> void:
	var customer := current_customer()
	sell_button.disabled = transition_lock or customer.is_empty() or selected_uid.is_empty() or selected_potion_id != StringName(str(customer.get("potion", ""))) or _find_instance(selected_potion_id, selected_uid).is_empty()


func _on_sell_pressed() -> void:
	if sell_button.disabled or night_result == null:
		return
	transition_lock = true
	sell_button.disabled = true
	var instance := _find_instance(selected_potion_id, selected_uid)
	var potion: PotionData = _potion_by_id.get(selected_potion_id)
	var value := _sale_value(potion, instance, float(current_customer().get("modifier", 1.0)))
	var sold: Array = night_result.sold_potions.get(selected_potion_id, [])
	sold.append(selected_uid)
	night_result.sold_potions[selected_potion_id] = sold
	night_result.earned_money += value
	session_earnings += value
	feedback.flash("成交 +%d曜" % value, true)
	_advance_customer()


func _on_reject_pressed() -> void:
	if transition_lock or current_customer().is_empty():
		return
	feedback.flash("已婉拒顾客，未改变永久数据。", false)
	_advance_customer()


func _advance_customer() -> void:
	current_index += 1
	selected_potion_id = &""
	selected_uid = ""
	transition_lock = false
	_refresh()


func _on_end_pressed() -> void:
	request_return.emit()


func _on_confirmed_end() -> void:
	request_return.emit()


func _potion_name(potion_id: StringName) -> String:
	var potion: PotionData = _potion_by_id.get(potion_id)
	return potion.display_name if potion != null else str(potion_id)


func _find_instance(potion_id: StringName, uid: String) -> Dictionary:
	if player_data == null:
		return {}
	for item: Variant in player_data.potions.get(potion_id, []):
		if item is Dictionary and str((item as Dictionary).get("instance_uid", "")) == uid:
			return item as Dictionary
	return {}


func _is_sold(uid: String) -> bool:
	if night_result == null:
		return false
	for values: Variant in night_result.sold_potions.values():
		if values is Array and (values as Array).has(uid):
			return true
	return false


func _sale_value(potion: PotionData, instance: Dictionary, modifier: float) -> int:
	if potion == null or instance.is_empty():
		return 0
	return maxi(roundi(float(potion.base_price) * clampf(float(instance.get("remaining_dose", 1.0)), 0.0, 1.0) * maxf(float(instance.get("price_multiplier", 1.0)), 0.1) * modifier), 0)
