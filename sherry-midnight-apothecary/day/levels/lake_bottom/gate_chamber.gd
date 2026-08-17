class_name GateChamberLevel
extends DayLevelEnvironment

@export var local_hud_enabled := true

@onready var objective_label: Label = get_node_or_null("LocalHUD/Panel/VBox/Objective")
@onready var hint_label: Label = get_node_or_null("LocalHUD/Panel/VBox/Hint")

func _ready() -> void:
	super._ready()
	if get_node_or_null("LocalHUD"):
		$LocalHUD.visible = local_hud_enabled
	_set_objective("旧旅门维护站内部", "调查室内的古老中继机关与大司鱼的痕迹。")

func on_level_entered(_entry_id: StringName) -> void:
	_set_objective("旧旅门维护站内部", "调查室内的古老中继机关与大司鱼的痕迹。")

func _set_objective(text: String, hint: String = "") -> void:
	if objective_label:
		objective_label.text = text
	if hint_label:
		hint_label.text = hint
