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
const MAX_PATIENCE := 100.0
const REFUSAL_PATIENCE_LOSS := 25.0
const WALKOUT_REPUTATION_LOSS := 10
const MIN_SATISFACTION := 0.5
const MAX_SATISFACTION := 1.5

@onready var night_label: Label = %NightLabel
@onready var progress_label: Label = %ProgressLabel
@onready var economy_label: Label = %EconomyLabel
@onready var request_card: CustomerRequestCard = %CustomerRequestCard
@onready var customer_portrait: TextureRect = %CustomerPortrait
@onready var patience_text: Label = $RootVBox/Columns/CenterPanel/CenterMargin/CenterVBox/PatienceText
@onready var patience_bar: ProgressBar = $RootVBox/Columns/CenterPanel/CenterMargin/CenterVBox/PatienceBar
@onready var potion_shelf_panel: Variant = %PotionShelfPanel
@onready var sell_button: Button = %SellButton
@onready var reject_button: Button = %RejectButton
@onready var end_button: Button = %EndButton
@onready var feedback: SaleFeedback = %SaleFeedback
@onready var confirm_dialog: ConfirmationDialog = %ConfirmDialog

var player_data: PlayerData
var night_result: NightResult
var day := 1
var completed_customer_count := 0
var selected_potion_id: StringName = &""
var selected_uid := ""
var transition_lock := false
var session_earnings := 0
var _potion_by_id: Dictionary = {}
var _customer_queue: Array[Dictionary] = []


func _ready() -> void:
	for potion: PotionData in POTIONS:
		_potion_by_id[potion.id] = potion
	potion_shelf_panel.potion_selected.connect(_on_potion_chosen)
	_refresh()


func setup(shared_player_data: PlayerData, shared_night_result: NightResult, current_day: int) -> void:
	player_data = shared_player_data
	night_result = shared_night_result
	day = maxi(current_day, 1)
	completed_customer_count = 0
	selected_potion_id = &""
	selected_uid = ""
	session_earnings = 0
	_customer_queue = _build_customer_queue()
	if is_node_ready():
		_refresh()


func _build_customer_queue() -> Array[Dictionary]:
	var reputation := player_data.store_reputation if player_data != null else 100
	var available: Array[Dictionary] = []
	for customer: Dictionary in CUSTOMERS:
		if reputation >= 70 or float(customer.get("modifier", 1.0)) <= 1.05:
			available.append(customer)
	var target_count := 3 if reputation >= 70 else 2 if reputation >= 40 else 1
	var queue: Array[Dictionary] = []
	for index in range(mini(target_count, available.size())):
		var customer := available[index].duplicate()
		if reputation < 70:
			customer["modifier"] = float(customer.get("modifier", 1.0)) * 0.9
		if reputation < 40:
			customer["modifier"] = float(customer.get("modifier", 1.0)) * 0.85
			customer["identity"] = "谨慎的" + str(customer.get("identity", "顾客"))
		customer["patience"] = MAX_PATIENCE
		queue.append(customer)
	return queue


func refresh_from_runtime() -> void:
	_refresh()


func current_customer() -> Dictionary:
	return _customer_queue.front() if not _customer_queue.is_empty() else {}


func _refresh() -> void:
	if not is_node_ready():
		return
	night_label.text = "第 %02d 夜 · 营业白模" % day
	progress_label.text = "已接待 %d · 等候 %d" % [completed_customer_count, _customer_queue.size()]
	var wallet := player_data.money if player_data != null else 0
	var debt := player_data.debt if player_data != null else 30000
	var reputation := player_data.store_reputation if player_data != null else 100
	var pending_reputation := night_result.reputation_delta if night_result != null else 0
	economy_label.text = "待结算 +%d曜 · 持有 %d曜 · 债务 %d曜 · 声誉 %d%s" % [night_result.earned_money if night_result != null else 0, wallet, debt, reputation, "（本夜 %d）" % pending_reputation if pending_reputation != 0 else ""]
	var customer := current_customer()
	var complete := customer.is_empty()
	if complete:
		request_card.visible = false
		customer_portrait.texture = null
		patience_text.visible = false
		patience_bar.value = 0.0
		potion_shelf_panel.set_selection_text("今晚的顾客已经全部接待完毕。")
		sell_button.disabled = true
		reject_button.disabled = true
	else:
		request_card.visible = true
		request_card.show_customer(customer, _potion_name(customer.potion))
		customer_portrait.texture = customer.portrait
		var patience := float(customer.get("patience", MAX_PATIENCE))
		patience_text.visible = true
		patience_text.text = "耐心 %d / %d" % [roundi(patience), roundi(MAX_PATIENCE)]
		patience_bar.value = patience
		reject_button.disabled = transition_lock
	_refresh_shelf()
	_update_sale_button()


func _refresh_shelf() -> void:
	potion_shelf_panel.clear_items()
	selected_potion_id = &"" if _find_instance(selected_potion_id, selected_uid).is_empty() else selected_potion_id
	if player_data == null:
		potion_shelf_panel.show_empty_message("暂无药水。请先到制药台制作。")
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
			var price := _sale_value(potion, instance, float(current_customer().get("modifier", 1.0)))
			potion_shelf_panel.add_potion(potion, instance, price, selected_uid == uid)
	if count == 0:
		potion_shelf_panel.show_empty_message("货架为空，或本夜的药水已经售出。")


func _on_potion_chosen(potion_id: StringName, uid: String) -> void:
	if transition_lock or _is_sold(uid):
		return
	selected_potion_id = potion_id
	selected_uid = uid
	var potion: PotionData = _potion_by_id.get(potion_id)
	potion_shelf_panel.set_selection_text("已选择：%s · 报价 %d曜" % [potion.display_name if potion != null else str(potion_id), _sale_value(potion, _find_instance(potion_id, uid), float(current_customer().get("modifier", 1.0)))])
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
	var satisfaction := _customer_satisfaction(instance)
	var reputation_gain := _reputation_gain_for_satisfaction(satisfaction)
	night_result.reputation_delta += reputation_gain
	session_earnings += value
	_flash_sale_feedback(value, satisfaction, reputation_gain)
	_complete_current_customer()


func _on_reject_pressed() -> void:
	if transition_lock or current_customer().is_empty():
		return
	var customer: Dictionary = _customer_queue.pop_front()
	var remaining_patience := maxf(float(customer.get("patience", MAX_PATIENCE)) - REFUSAL_PATIENCE_LOSS, 0.0)
	customer["patience"] = remaining_patience
	if remaining_patience > 0.0:
		_customer_queue.append(customer)
		_flash_rejection_feedback(customer, false)
	else:
		completed_customer_count += 1
		if night_result != null:
			night_result.reputation_delta -= WALKOUT_REPUTATION_LOSS
		_flash_rejection_feedback(customer, true)
	selected_potion_id = &""
	selected_uid = ""
	_refresh()


func _flash_rejection_feedback(customer: Dictionary, walked_out: bool) -> void:
	if feedback == null:
		return
	if walked_out:
		feedback.flash("%s 失去耐心并离开，店铺声誉 -%d。" % [customer.get("name", "顾客"), WALKOUT_REPUTATION_LOSS], false)
	else:
		feedback.flash("%s 回到队尾，耐心 -%d。" % [customer.get("name", "顾客"), roundi(REFUSAL_PATIENCE_LOSS)], false)


func _flash_sale_feedback(value: int, satisfaction: float, reputation_gain: int) -> void:
	if feedback != null:
		feedback.flash("成交 +%d曜 · 满意度 %.0f%% · 声誉 +%d" % [value, satisfaction * 100.0, reputation_gain], true)


func _complete_current_customer() -> void:
	if not _customer_queue.is_empty():
		_customer_queue.pop_front()
		completed_customer_count += 1
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


func _customer_satisfaction(instance: Dictionary) -> float:
	return clampf(float(instance.get("quality", 1.0)) * clampf(float(instance.get("remaining_dose", 1.0)), 0.0, 1.0), MIN_SATISFACTION, MAX_SATISFACTION)


func _reputation_gain_for_satisfaction(satisfaction: float) -> int:
	var normalized := inverse_lerp(MIN_SATISFACTION, MAX_SATISFACTION, clampf(satisfaction, MIN_SATISFACTION, MAX_SATISFACTION))
	return roundi(lerpf(1.0, 5.0, normalized))
