class_name ShopRuntime
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
const MAX_PATIENCE := 100.0
const REFUSAL_PATIENCE_LOSS := 25.0
const PATIENCE_RECOVERY_ON_PERFECT := 25.0
const MIN_SATISFACTION := 0.5
const MAX_SATISFACTION := 1.5

@onready var night_label: Label = %NightLabel
@onready var progress_label: Label = %ProgressLabel
@onready var economy_label: Label = %EconomyLabel
@onready var request_card: CustomerRequestCard = %CustomerRequestCard
@onready var potion_detail: Label = %PotionDetail
@onready var potion_tooltip: PanelContainer = %PotionTooltip
@onready var potion_tooltip_label: Label = %Label
@onready var customer_portrait: TextureRect = %CustomerPortrait
@onready var patience_text: Label = $RootVBox/Columns/CenterPanel/CenterMargin/CenterVBox/PatienceText
@onready var patience_bar: ProgressBar = $RootVBox/Columns/CenterPanel/CenterMargin/CenterVBox/PatienceBar
@onready var potion_shelf_panel: Variant = %PotionShelfPanel
@onready var sell_button: Button = %SellButton
@onready var reject_button: Button = %RejectButton
@onready var end_button: Button = %EndButton
@onready var feedback: SaleFeedback = %SaleFeedback
@onready var confirm_dialog: ConfirmationDialog = %ConfirmDialog
@onready var reject_confirm_dialog: ConfirmationDialog = get_node_or_null("%RejectConfirmDialog")

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
	potion_shelf_panel.potion_hovered.connect(_on_potion_hovered)
	potion_shelf_panel.potion_unhovered.connect(_hide_potion_tooltip)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		request_return.emit()
		get_viewport().set_input_as_handled()


func setup(shared_player_data: PlayerData, shared_night_result: NightResult, current_day: int) -> void:
	player_data = shared_player_data
	night_result = shared_night_result
	day = maxi(current_day, 0)
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
	for customer: Dictionary in CustomerEventCatalog.eligible_for_day(day, player_data.tutorial_flags if player_data != null else {}, player_data.customer_states if player_data != null else {}):
		var npc_id := str(customer.get("npc_id", customer.get("event_id", "customer")))
		var customer_state: Dictionary = player_data.customer_states.get(npc_id, {}) if player_data != null else {}
		if bool(customer_state.get("permanently_lost", false)) or float(customer_state.get("patience", MAX_PATIENCE)) <= 0.0:
			continue
		if reputation >= 70 or float(customer.get("modifier", 1.0)) <= 1.05:
			available.append(customer)
	available.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_due := bool(a.get("is_due_followup", false))
		var b_due := bool(b.get("is_due_followup", false))
		if a_due != b_due:
			return a_due
		var a_key := ("%d:%s" % [day, str(a.get("npc_id", ""))]).hash()
		var b_key := ("%d:%s" % [day, str(b.get("npc_id", ""))]).hash()
		return a_key < b_key
	)
	var reputation_cap := 8 if reputation >= 70 else 2 if reputation >= 40 else 1
	var target_count := mini(CustomerEventCatalog.customer_cap_for_day(day), reputation_cap)
	var queue: Array[Dictionary] = []
	for index in range(mini(target_count, available.size())):
		var customer := available[index].duplicate()
		var npc_id := str(customer.get("npc_id", customer.get("event_id", "customer")))
		var customer_state: Dictionary = player_data.customer_states.get(npc_id, {}) if player_data != null else {}
		var saved_patience := float(customer_state.get("patience", MAX_PATIENCE))
		if reputation < 70:
			customer["modifier"] = float(customer.get("modifier", 1.0)) * 0.9
		if reputation < 40:
			customer["modifier"] = float(customer.get("modifier", 1.0)) * 0.85
			customer["identity"] = "谨慎的" + str(customer.get("identity", "顾客"))
		customer["patience"] = saved_patience
		queue.append(customer)
	return queue


func refresh_from_runtime() -> void:
	_refresh()


func current_customer() -> Dictionary:
	return _customer_queue.front() if not _customer_queue.is_empty() else {}


func get_remaining_customer_count() -> int:
	return _customer_queue.size()


func get_completed_customer_count() -> int:
	return completed_customer_count


func has_operated() -> bool:
	return completed_customer_count > 0 or session_earnings > 0 or (night_result != null and not night_result.sold_potions.is_empty())


func _refresh() -> void:
	if not is_node_ready():
		return
	night_label.text = "教程夜 · 营业" if day == 0 else "第 %02d 夜 · 营业" % day
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
		if potion_shelf_panel != null:
			potion_shelf_panel.set_selection_text("今晚的顾客已经全部接待完毕。")
		sell_button.disabled = true
		reject_button.disabled = true
	else:
		request_card.visible = true
		request_card.show_customer(customer)
		customer_portrait.texture = customer.portrait
		var patience := float(customer.get("patience", MAX_PATIENCE))
		patience_text.visible = true
		patience_text.text = "耐心 %d / %d" % [roundi(patience), roundi(MAX_PATIENCE)]
		patience_bar.value = patience
		reject_button.disabled = transition_lock
	_refresh_shelf()
	_update_sale_button()


func _refresh_shelf() -> void:
	if potion_shelf_panel == null:
		return
	potion_shelf_panel.clear_items()
	selected_potion_id = &"" if _find_instance(selected_potion_id, selected_uid).is_empty() else selected_potion_id
	if player_data == null:
		potion_shelf_panel.show_empty_message("暂无药水。请先到制药台制作。")
		return
	var count := 0
	for potion: PotionData in POTIONS:
		for item: Variant in _available_instances(potion.id):
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
	if potion_shelf_panel != null:
		potion_shelf_panel.set_selection_text("已选择：%s · 报价 %d曜" % [potion.display_name if potion != null else str(potion_id), _sale_value(potion, _find_instance(potion_id, uid), float(current_customer().get("modifier", 1.0)))])
	_update_sale_button()


func _on_potion_hovered(potion: PotionData, instance: Dictionary, price: int) -> void:
	if potion_tooltip == null or potion_tooltip_label == null:
		return
	var display_name := str(instance.get("custom_name", "")).strip_edges()
	if display_name.is_empty():
		display_name = potion.display_name
	var secondary := StringName(str(instance.get("secondary_effect_id", "")))
	potion_tooltip_label.text = "%s\n品质 %.0f%% · 剩余 %.0f%% · 报价 %d曜\n主作用：%s%s" % [
		display_name,
		float(instance.get("quality", 1.0)) * 100.0,
		clampf(float(instance.get("remaining_dose", 1.0)), 0.0, 1.0) * 100.0,
		price,
		PotionEffectText.describe_potion(potion),
		"\n副作用：%s × %.2f" % [PotionEffectText.describe(secondary), float(instance.get("secondary_effect_multiplier", 0.0))] if secondary != &"" else "",
	]
	potion_tooltip.show()
	_update_potion_tooltip_position()


func _hide_potion_tooltip() -> void:
	if potion_tooltip != null:
		potion_tooltip.hide()


func _process(_delta: float) -> void:
	if potion_tooltip != null and potion_tooltip.visible:
		_update_potion_tooltip_position()


func _update_potion_tooltip_position() -> void:
	var cursor := get_viewport().get_mouse_position() + Vector2(18, 18)
	var viewport_size := get_viewport_rect().size
	potion_tooltip.position = Vector2(minf(cursor.x, viewport_size.x - potion_tooltip.size.x - 8), minf(cursor.y, viewport_size.y - potion_tooltip.size.y - 8))


func _update_sale_button() -> void:
	var customer := current_customer()
	sell_button.disabled = transition_lock or customer.is_empty() or selected_uid.is_empty() or _find_instance(selected_potion_id, selected_uid).is_empty()


func _on_sell_pressed() -> void:
	if sell_button.disabled or night_result == null:
		return
	transition_lock = true
	sell_button.disabled = true
	var instance := _find_instance(selected_potion_id, selected_uid)
	var potion: PotionData = _potion_by_id.get(selected_potion_id)
	var customer := current_customer()
	var value := _sale_value(potion, instance, float(customer.get("modifier", 1.0)))
	var match := PotionMatchService.calculate(customer, potion, instance)
	var customer_feedback := CustomerFeedbackResolver.resolve(customer, match)
	var sold: Array = night_result.sold_potions.get(selected_potion_id, [])
	sold.append(selected_uid)
	night_result.sold_potions[selected_potion_id] = sold
	night_result.earned_money += value
	var satisfaction := _customer_satisfaction(instance)
	var reputation_gain := customer_feedback.reputation_delta
	night_result.reputation_delta += reputation_gain
	session_earnings += value

	var patience_recovered := 0.0
	if match.outcome == PotionMatchResult.Outcome.PERFECT or match.outcome == PotionMatchResult.Outcome.SPECIAL:
		var current_patience := float(customer.get("patience", MAX_PATIENCE))
		var new_patience := minf(current_patience + PATIENCE_RECOVERY_ON_PERFECT, MAX_PATIENCE)
		patience_recovered = new_patience - current_patience
		customer["patience"] = new_patience

	_record_customer_result(customer, instance, match, customer_feedback)
	_flash_sale_feedback(value, satisfaction, reputation_gain, customer_feedback.immediate_text, patience_recovered, float(customer.get("patience", MAX_PATIENCE)))
	_complete_current_customer()


func _on_reject_pressed() -> void:
	if transition_lock or current_customer().is_empty():
		return
	var customer: Dictionary = current_customer()
	var current_patience := float(customer.get("patience", MAX_PATIENCE))
	if current_patience <= REFUSAL_PATIENCE_LOSS:
		_show_reject_confirm_dialog(customer)
	else:
		_execute_reject(customer)


func _show_reject_confirm_dialog(customer: Dictionary) -> void:
	var customer_name := str(customer.get("name", "顾客"))
	var current_patience := roundi(float(customer.get("patience", MAX_PATIENCE)))
	if reject_confirm_dialog != null:
		reject_confirm_dialog.dialog_text = "该顾客（%s）当前耐心仅剩 %d%%。\n再次拒绝将扣除 25%% 耐心并导致耐心归零，该顾客将永久离开药水铺，之后不再光顾！\n\n确定要拒绝该顾客吗？" % [customer_name, current_patience]
		reject_confirm_dialog.popup_centered()
	else:
		_execute_reject(customer)


func _on_reject_confirmed() -> void:
	if current_customer().is_empty():
		return
	_execute_reject(current_customer())


func _execute_reject(customer: Dictionary) -> void:
	if _customer_queue.is_empty():
		return
	_customer_queue.pop_front()
	completed_customer_count += 1

	var npc_id := str(customer.get("npc_id", customer.get("event_id", "customer")))
	var state: Dictionary = player_data.customer_states.get(npc_id, {}) if player_data != null else {}
	var refusal_count := int(state.get("refusal_count", 0)) + 1
	state["refusal_count"] = refusal_count

	var remaining_patience := maxf(float(customer.get("patience", MAX_PATIENCE)) - REFUSAL_PATIENCE_LOSS, 0.0)
	customer["patience"] = remaining_patience
	state["patience"] = remaining_patience
	state["next_visit_day"] = day + 2
	state["case_stage"] = int(customer.get("case_stage", state.get("case_stage", 0)))
	state["case_branch"] = str(customer.get("case_branch", state.get("case_branch", "normal")))

	var reputation_penalty := int(pow(2.0, refusal_count))
	if night_result != null:
		night_result.reputation_delta -= reputation_penalty

	if remaining_patience <= 0.0:
		state["permanently_lost"] = true
		_flash_rejection_feedback(customer, reputation_penalty, true)
	else:
		_flash_rejection_feedback(customer, reputation_penalty, false)

	if player_data != null:
		player_data.customer_states[npc_id] = state

	selected_potion_id = &""
	selected_uid = ""
	_refresh()


func _flash_rejection_feedback(customer: Dictionary, reputation_penalty: int, permanently_lost: bool) -> void:
	if feedback == null:
		return
	var customer_name := str(customer.get("name", "顾客"))
	if permanently_lost:
		feedback.flash("%s 耐心耗尽，已永久离开药水铺！店铺声誉 -%d。" % [customer_name, reputation_penalty], false)
	else:
		feedback.flash("%s 离开了药水铺，耐心 -25%%（剩余 %.0f%%），店铺声誉 -%d。" % [customer_name, float(customer.get("patience", 0.0)), reputation_penalty], false)


func _flash_sale_feedback(value: int, satisfaction: float, reputation_gain: int, text: String, patience_recovered: float = 0.0, current_patience: float = 100.0) -> void:
	if feedback != null:
		var recovery_text := " · 耐心 +%.0f%%（当前 %.0f%%）" % [patience_recovered, current_patience] if patience_recovered > 0.0 else ""
		feedback.flash("%s\n成交 +%d曜 · 满意度 %.0f%% · 声誉 %+d%s" % [text, value, satisfaction * 100.0, reputation_gain, recovery_text], reputation_gain >= 0)


func _record_customer_result(customer: Dictionary, instance: Dictionary, match: PotionMatchResult, result: CustomerFeedbackResult) -> void:
	if player_data == null:
		return
	var npc_id := str(customer.get("npc_id", customer.get("event_id", "customer")))
	var state: Dictionary = player_data.customer_states.get(npc_id, {})
	state["visit_count"] = int(state.get("visit_count", 0)) + 1
	state["last_visit_day"] = day
	state["next_visit_day"] = day + result.revisit_after_days if result.schedule_revisit else 0
	state["last_outcome"] = str(match.outcome_id()).to_lower()
	state["relationship"] = int(state.get("relationship", 0)) + result.relationship_delta
	state["patience"] = float(customer.get("patience", MAX_PATIENCE))
	var selected_potion: PotionData = _potion_by_id.get(selected_potion_id)
	state["last_treatment"] = {
		"primary_effect": str(PotionMatchService.effect_for(selected_potion.main_effect_id)) if selected_potion != null else "",
		"secondary_effect": str(PotionMatchService.effect_for(StringName(str(instance.get("secondary_effect_id", ""))))),
		"traits": instance.get("traits", []),
		"potency": instance.get("potency", 1.0),
		"score": match.total_score,
	}
	state["last_feedback"] = result.immediate_text
	var current_stage := int(customer.get("case_stage", state.get("case_stage", 0)))
	match match.outcome:
		PotionMatchResult.Outcome.PERFECT, PotionMatchResult.Outcome.SPECIAL, PotionMatchResult.Outcome.SATISFIED:
			state["case_stage"] = current_stage + 1
			state["case_branch"] = "normal"
		PotionMatchResult.Outcome.ACCEPTABLE:
			state["case_stage"] = current_stage
			state["case_branch"] = "normal"
		PotionMatchResult.Outcome.FAILED, PotionMatchResult.Outcome.DANGEROUS:
			state["case_stage"] = current_stage
			state["case_branch"] = "worsened"
	player_data.customer_states[npc_id] = state
	if match.outcome == PotionMatchResult.Outcome.PERFECT or match.outcome == PotionMatchResult.Outcome.SPECIAL:
		player_data.tutorial_flags[str(customer.get("success_flag", ""))] = true
	if result.special_event_id != &"":
		player_data.tutorial_flags[str(result.special_event_id)] = true


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
	for item: Variant in _available_instances(potion_id):
		if item is Dictionary and str((item as Dictionary).get("instance_uid", "")) == uid:
			return item as Dictionary
	return {}


func _available_instances(potion_id: StringName) -> Array:
	var instances: Array = []
	if player_data != null:
		instances.append_array(player_data.potions.get(potion_id, []))
	if night_result != null:
		for item: Variant in night_result.produced_potions.get(potion_id, []):
			if item is Dictionary and not instances.any(func(current: Dictionary) -> bool: return str(current.get("instance_uid", "")) == str((item as Dictionary).get("instance_uid", ""))):
				instances.append(item)
	return instances


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
