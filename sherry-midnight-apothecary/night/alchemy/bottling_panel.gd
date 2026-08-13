class_name BottlingPanel
extends PanelContainer

signal confirmed(style_id: StringName, custom_name: String)

const BOTTLE_SCENE := preload("res://shared/potions/ui/potion_bottle_visual.tscn")

@onready var preview: PotionBottleVisual = %Preview
@onready var name_input: LineEdit = %NameInput
@onready var quality_label: Label = %QualityLabel
@onready var effect_label: Label = %EffectLabel
@onready var style_row: HBoxContainer = %StyleRow

var potion: PotionData
var instance: Dictionary
var style_id: StringName = &"health"

func open_for(source_potion: PotionData, source_instance: Dictionary) -> void:
	potion = source_potion
	instance = source_instance.duplicate(true)
	style_id = StringName(str(instance.get("bottle_style_id", "health")))
	name_input.text = str(instance.get("custom_name", ""))
	quality_label.text = "评级：%s（%.2f）" % [_quality_name(float(instance.get("quality", 1.0))), float(instance.get("quality", 1.0))]
	var main := PotionEffectText.describe(potion.main_effect_id)
	var secondary := StringName(str(instance.get("secondary_effect_id", "")))
	effect_label.text = "主作用：%s" % main
	if secondary != &"": effect_label.text += "\n副作用：%s × %.2f" % [PotionEffectText.describe(secondary), float(instance.get("secondary_effect_multiplier", 0.0))]
	for child in style_row.get_children(): child.queue_free()
	for style: StringName in PotionBottleVisual.STYLES:
		var button := Button.new()
		button.text = str(style)
		button.toggle_mode = true
		button.button_pressed = style == style_id
		button.pressed.connect(func() -> void: _select_style(style))
		style_row.add_child(button)
	visible = true
	_refresh_preview()

func _select_style(next_style: StringName) -> void:
	style_id = next_style
	_refresh_preview()

func _refresh_preview() -> void:
	instance["bottle_style_id"] = str(style_id)
	preview.show_instance(potion, instance)

func _on_confirm_pressed() -> void:
	confirmed.emit(style_id, name_input.text.strip_edges().left(12))
	visible = false

func _quality_name(value: float) -> String:
	if value >= 1.25: return "卓越"
	if value >= 0.9: return "良好"
	if value >= 0.6: return "普通"
	return "粗劣"
