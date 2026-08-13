class_name BusinessPlaceholder
extends Control

signal request_return

const CUSTOMER_COUNT := 3
const POTION_DEFINITIONS: Array[PotionData] = [
	preload("res://shared/definitions/data/potions/red_potion.tres"),
	preload("res://shared/definitions/data/potions/orange_potion.tres"),
	preload("res://shared/definitions/data/potions/yellow_potion.tres"),
	preload("res://shared/definitions/data/potions/green_potion.tres"),
	preload("res://shared/definitions/data/potions/cyan_potion.tres"),
	preload("res://shared/definitions/data/potions/blue_potion.tres"),
	preload("res://shared/definitions/data/potions/purple_potion.tres"),
	preload("res://shared/definitions/data/potions/purification_potion.tres"),
]
const CUSTOMERS: Array[CustomerData] = [
	preload("res://shared/definitions/data/customers/young_villager.tres"),
	preload("res://shared/definitions/data/customers/herbalist.tres"),
	preload("res://shared/definitions/data/customers/blacksmith.tres"),
	preload("res://shared/definitions/data/customers/scholar.tres"),
	preload("res://shared/definitions/data/customers/town_guard.tres"),
]

@onready var money_label: Label = %MoneyLabel
@onready var debt_label: Label = %DebtLabel
@onready var progress_label: Label = %ProgressLabel
@onready var customer_name_label: Label = %CustomerNameLabel
@onready var customer_portrait: TextureRect = %CustomerPortrait
@onready var request_label: Label = %RequestLabel
@onready var request_potion_label: Label = %RequestPotionLabel
@onready var offer_list: VBoxContainer = %OfferList
@onready var selection_label: Label = %SelectionLabel
@onready var feedback_label: Label = %FeedbackLabel
@onready var serve_button: Button = %ServeButton
@onready var reject_button: Button = %RejectButton
@onready var finish_button: Button = %FinishButton

var player_data: PlayerData
var night_result: NightResult
var day := 1
var customer_index := 0
var served_count := 0
var rejected_count := 0
var session_earnings := 0
var selected_potion_id: StringName = &""
var selected_instance_uid := ""
var _queue: Array[CustomerData] = []
var _potion_by_id: Dictionary = {}


func _ready() -> void:
	for potion: PotionData in POTION_DEFINITIONS:
		_potion_by_id[potion.id] = potion
	serve_button.pressed.connect(_on_serve_button_pressed)
	reject_button.pressed.connect(_on_reject_button_pressed)
	finish_button.pressed.connect(_on_return_button_pressed)
	_refresh()


func setup(shared_player_data: PlayerData, shared_night_result: NightResult, current_day: int) -> void:
	player_data = shared_player_data
	night_result = shared_night_result
	day = maxi(current_day, 1)
	customer_index = 0
	served_count = 0
	rejected_count = 0
	session_earnings = 0
	selected_potion_id = &""
	selected_instance_uid = ""
	_build_queue()
	if is_node_ready():
		_refresh()


func refresh_from_runtime() -> void:
	_refresh()


func select_offer(potion_id: StringName, instance_uid: String) -> void:
	if _is_instance_sold(instance_uid):
		return
	selected_potion_id = potion_id
	selected_instance_uid = instance_uid
	feedback_label.text = ""
	_refresh_offer_list()
	_refresh_selection()


func serve_selected() -> bool:
	var customer := current_customer()
	if customer == null or player_data == null or night_result == null:
		return false
	if selected_potion_id == &"" or selected_instance_uid.is_empty():
		feedback_label.text = "请先从右侧货架选择一瓶药水。"
		return false
	var requested_id := current_request_potion_id()
	if selected_potion_id != requested_id:
		feedback_label.text = "这不是顾客需要的药水。"
		return false
	var instance := _find_available_instance(selected_potion_id, selected_instance_uid)
	if instance.is_empty():
		feedback_label.text = "这瓶药水已经售出。"
		return false
	var potion: PotionData = _potion_by_id.get(selected_potion_id)
	var value := _calculate_sale_value(potion, instance, customer.price_multiplier)
	var sold: Array = night_result.sold_potions.get(selected_potion_id, [])
	sold.append(selected_instance_uid)
	night_result.sold_potions[selected_potion_id] = sold
	night_result.earned_money += value
	session_earnings += value
	served_count += 1
	_advance_customer("成交 +%d曜" % value)
	return true


func reject_customer() -> bool:
	if current_customer() == null:
		return false
	rejected_count += 1
	_advance_customer("已婉拒这位顾客。")
	return true


func current_customer() -> CustomerData:
	return _queue[customer_index] if customer_index >= 0 and customer_index < _queue.size() else null


func current_request_potion_id() -> StringName:
	var customer := current_customer()
	if customer == null or customer.preferred_potion_ids.is_empty():
		return &""
	return customer.preferred_potion_ids[day % customer.preferred_potion_ids.size()]


func is_session_complete() -> bool:
	return customer_index >= _queue.size() and not _queue.is_empty()


func _build_queue() -> void:
	_queue.clear()
	for offset in range(mini(CUSTOMER_COUNT, CUSTOMERS.size())):
		_queue.append(CUSTOMERS[(day - 1 + offset) % CUSTOMERS.size()])


func _advance_customer(message: String) -> void:
	customer_index += 1
	selected_potion_id = &""
	selected_instance_uid = ""
	_refresh()
	feedback_label.text = message if not is_session_complete() else "%s  今夜营业完成。" % message


func _refresh() -> void:
	if not is_node_ready():
		return
	var shown_money := player_data.money if player_data != null else 0
	var shown_debt := player_data.debt if player_data != null else 30000
	money_label.text = "持有 %d曜" % shown_money
	debt_label.text = "债务 %d曜" % shown_debt
	progress_label.text = "第%d夜  ·  顾客 %d/%d  ·  今夜收入 %d曜" % [day, mini(customer_index + 1, CUSTOMER_COUNT), CUSTOMER_COUNT, session_earnings]
	var customer := current_customer()
	if customer == null:
		customer_name_label.text = "营业结束"
		customer_portrait.texture = null
		request_label.text = "今晚的顾客已经全部接待完毕。"
		request_potion_label.text = "成交 %d 单 · 婉拒 %d 单" % [served_count, rejected_count]
		serve_button.disabled = true
		reject_button.disabled = true
		finish_button.text = "返回店内"
	else:
		customer_name_label.text = customer.display_name
		customer_portrait.texture = customer.portrait
		request_label.text = customer.request_text
		var potion: PotionData = _potion_by_id.get(current_request_potion_id())
		request_potion_label.text = "需求：%s × 1" % (potion.display_name if potion != null else "未知药水")
		serve_button.disabled = false
		reject_button.disabled = false
		finish_button.text = "暂时收摊"
	_refresh_offer_list()
	_refresh_selection()


func _refresh_offer_list() -> void:
	for child in offer_list.get_children():
		offer_list.remove_child(child)
		child.queue_free()
	if player_data == null:
		_add_empty_offer("暂无可售药水。请先在制药台制作药水。")
		return
	var offer_count := 0
	for potion: PotionData in POTION_DEFINITIONS:
		for value: Variant in _all_instances(potion.id):
			if value is not Dictionary:
				continue
			var instance := value as Dictionary
			var uid := str(instance.get("instance_uid", ""))
			if uid.is_empty() or _is_instance_sold(uid) or float(instance.get("remaining_dose", 1.0)) <= 0.0001:
				continue
			offer_count += 1
			var button := Button.new()
			var price := _calculate_sale_value(potion, instance, current_customer().price_multiplier if current_customer() != null else 1.0)
			button.text = "%s  品质 %.0f%%  ·  %d曜" % [potion.display_name, float(instance.get("quality", 1.0)) * 100.0, price]
			button.custom_minimum_size.y = 48.0
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.toggle_mode = true
			button.button_pressed = selected_instance_uid == uid
			button.pressed.connect(select_offer.bind(potion.id, uid))
			offer_list.add_child(button)
	if offer_count == 0:
		_add_empty_offer("货架已空。可以婉拒顾客或暂时收摊。")


func _add_empty_offer(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = Color(0.72, 0.72, 0.72)
	offer_list.add_child(label)


func _refresh_selection() -> void:
	if selected_instance_uid.is_empty():
		selection_label.text = "尚未选择药水"
		return
	var potion: PotionData = _potion_by_id.get(selected_potion_id)
	selection_label.text = "已选择：%s" % (potion.display_name if potion != null else str(selected_potion_id))


func _find_available_instance(potion_id: StringName, instance_uid: String) -> Dictionary:
	if player_data == null or _is_instance_sold(instance_uid):
		return {}
	for value: Variant in _all_instances(potion_id):
		if value is Dictionary and str((value as Dictionary).get("instance_uid", "")) == instance_uid:
			return value as Dictionary
	return {}


func _all_instances(potion_id: StringName) -> Array:
	var result: Array = []
	if player_data != null:
		var stored: Variant = player_data.potions.get(potion_id, [])
		if stored is Array:
			result.append_array(stored as Array)
	if night_result != null:
		var produced: Variant = night_result.produced_potions.get(potion_id, [])
		if produced is Array:
			result.append_array(produced as Array)
	return result


func _is_instance_sold(instance_uid: String) -> bool:
	if night_result == null:
		return false
	for value: Variant in night_result.sold_potions.values():
		if value is Array and (value as Array).has(instance_uid):
			return true
	return false


func _calculate_sale_value(potion: PotionData, instance: Dictionary, customer_multiplier: float) -> int:
	if potion == null:
		return 0
	var remaining := clampf(float(instance.get("remaining_dose", 1.0)), 0.0, 1.0)
	var quality_price := maxf(float(instance.get("price_multiplier", 1.0)), 0.1)
	return maxi(roundi(float(potion.base_price) * remaining * quality_price * customer_multiplier), 0)


func _on_serve_button_pressed() -> void:
	serve_selected()


func _on_reject_button_pressed() -> void:
	reject_customer()


func _on_return_button_pressed() -> void:
	request_return.emit()
