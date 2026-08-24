class_name CustomerRequestCard
extends PanelContainer

@onready var title_label: Label = %TitleLabel
@onready var request_label: Label = %RequestLabel
@onready var detail_label: Label = %DetailLabel


func show_customer(customer: Dictionary, _potion_name: String = "") -> void:
	title_label.text = "%s · %s" % [customer.get("name", "顾客"), customer.get("identity", "夜间顾客")]
	request_label.text = str(customer.get("request", ""))
	var symptoms: Array = customer.get("visible_symptoms", [])
	var primary := StringName(str(customer.get("primary_need", "")))
	var secondary := StringName(str(customer.get("secondary_need", "")))
	var forbidden: Array = customer.get("forbidden_effects", [])
	var forbidden_names: Array[String] = []
	for effect_id in forbidden:
		forbidden_names.append(str(CustomerEventCatalog.EFFECT_NAMES.get(StringName(str(effect_id)), effect_id)))
	detail_label.text = "可见症状：%s\n主要需求：%s\n次要需求：%s\n病情强度：%d级\n明确禁忌：%s\n顾客品质  %s · 加价 × %.2f" % [
		"、".join(symptoms),
		CustomerEventCatalog.EFFECT_NAMES.get(primary, "未知"),
		CustomerEventCatalog.EFFECT_NAMES.get(secondary, "无") if secondary != &"" else "无",
		int(customer.get("severity", 1)),
		"、".join(forbidden_names) if not forbidden_names.is_empty() else "无",
		_quality_label(float(customer.get("modifier", 1.0))),
		float(customer.get("modifier", 1.0)),
	]


func _quality_label(modifier: float) -> String:
	if modifier >= 1.1:
		return "优质"
	if modifier >= 0.95:
		return "普通"
	return "低质"
