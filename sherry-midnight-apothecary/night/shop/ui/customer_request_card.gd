class_name CustomerRequestCard
extends PanelContainer

@onready var title_label: Label = %TitleLabel
@onready var request_label: Label = %RequestLabel
@onready var detail_label: Label = %DetailLabel


func show_customer(customer: Dictionary, potion_name: String) -> void:
	title_label.text = "%s · %s" % [customer.get("name", "顾客"), customer.get("identity", "夜间顾客")]
	request_label.text = str(customer.get("request", ""))
	detail_label.text = "需求  %s × 1\n顾客加价  × %.2f" % [potion_name, float(customer.get("modifier", 1.0))]
