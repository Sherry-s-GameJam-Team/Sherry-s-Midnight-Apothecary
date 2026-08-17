class_name BottlingPanel
extends PanelContainer

signal confirmed(style_id: StringName, custom_name: String)

const BOTTLE_SCENE := preload("res://shared/potions/ui/potion_bottle_visual.tscn")

const AVAILABLE_STYLES: Array[StringName] = [&"health", &"heart", &"ice", &"moon", &"sleep"]
const STYLE_NAMES: Dictionary = {
	&"health": "经典圆瓶",
	&"heart": "爱心魔瓶",
	&"ice": "棱晶冰瓶",
	&"moon": "新月圣瓶",
	&"sleep": "平底长颈瓶",
	&"black": "污浊黑瓶"
}

@onready var preview: PotionBottleVisual = %Preview
@onready var style_switcher_row: HBoxContainer = %StyleSwitcherRow
@onready var prev_style_button: Button = %PrevStyleButton
@onready var next_style_button: Button = %NextStyleButton
@onready var style_name_label: Label = %StyleNameLabel

@onready var quality_label: Label = %QualityLabel
@onready var main_effect_label: Label = %MainEffectLabel
@onready var secondary_effect_label: Label = %SecondaryEffectLabel

@onready var name_row: Control = %NameRow
@onready var name_input: LineEdit = %NameInput
@onready var confirm_button: Button = %ConfirmButton

# Backward compatibility aliases
var effect_label: Label:
	get:
		return main_effect_label
var style_row: Control:
	get:
		return style_switcher_row

var potion: PotionData
var instance: Dictionary
var style_id: StringName = &"health"
var default_potion_name: String = ""


func _ready() -> void:
	if prev_style_button:
		prev_style_button.pressed.connect(_on_prev_style_pressed)
	if next_style_button:
		next_style_button.pressed.connect(_on_next_style_pressed)
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_pressed)


func open_for(source_potion: PotionData, source_instance: Dictionary) -> void:
	potion = source_potion
	instance = source_instance.duplicate(true)

	var initial_style := StringName(str(instance.get("bottle_style_id", "health")))
	if initial_style == &"black" or not AVAILABLE_STYLES.has(initial_style):
		style_id = &"health"
	else:
		style_id = initial_style

	default_potion_name = _generate_default_potion_name(potion, instance)

	if name_row:
		name_row.visible = true
	if style_switcher_row:
		style_switcher_row.visible = true

	var existing_custom_name := str(instance.get("custom_name", "")).strip_edges()
	if name_input:
		name_input.text = existing_custom_name if not existing_custom_name.is_empty() else default_potion_name

	var quality_val := float(instance.get("quality", 1.0))
	if quality_label:
		quality_label.text = "❖ 品质评级：%s (%.2f)" % [_quality_name(quality_val), quality_val]

	var main_desc := PotionEffectText.describe(potion.main_effect_id) if potion else "无稳定药效"
	if main_effect_label:
		main_effect_label.text = "❖ 主效果：%s" % main_desc

	var sec_id := StringName(str(instance.get("secondary_effect_id", "")))
	if secondary_effect_label:
		if sec_id != &"":
			var sec_mult := float(instance.get("secondary_effect_multiplier", 1.0))
			secondary_effect_label.text = "✦ 副效果：%s (×%.2f)" % [PotionEffectText.describe(sec_id), sec_mult]
			secondary_effect_label.add_theme_color_override("font_color", Color(0.24, 0.38, 0.58, 1.0))
		else:
			secondary_effect_label.text = "✦ 副效果：无额外副效果"
			secondary_effect_label.add_theme_color_override("font_color", Color(0.55, 0.45, 0.35, 0.9))

	if confirm_button:
		confirm_button.text = "✦ 确认装瓶并入库 ✦"

	visible = true
	_update_style_display()
	_refresh_preview()


func show_auto_stored(source_potion: PotionData, source_instance: Dictionary) -> void:
	potion = source_potion
	instance = source_instance.duplicate(true)
	style_id = &"black"

	if name_row:
		name_row.visible = false
	if style_switcher_row:
		style_switcher_row.visible = false

	var quality_val := float(instance.get("quality", 0.3))
	if quality_label:
		quality_label.text = "❖ 炼制结果：粗劣报废 (%.2f)" % quality_val

	if main_effect_label:
		main_effect_label.text = "❖ 状态：药力失衡，发生严重焦糊/杂质污染"

	if secondary_effect_label:
		secondary_effect_label.text = "✦ 处理：黑药水已自动密封入库"
		secondary_effect_label.add_theme_color_override("font_color", Color(0.55, 0.25, 0.18, 1.0))

	if confirm_button:
		confirm_button.text = "✦ 确认并收纳 ✦"

	visible = true
	_refresh_preview()


func _on_prev_style_pressed() -> void:
	var idx := AVAILABLE_STYLES.find(style_id)
	if idx == -1:
		idx = 0
	idx = (idx - 1 + AVAILABLE_STYLES.size()) % AVAILABLE_STYLES.size()
	_select_style(AVAILABLE_STYLES[idx])


func _on_next_style_pressed() -> void:
	var idx := AVAILABLE_STYLES.find(style_id)
	if idx == -1:
		idx = 0
	idx = (idx + 1) % AVAILABLE_STYLES.size()
	_select_style(AVAILABLE_STYLES[idx])


func _select_style(next_style: StringName) -> void:
	style_id = next_style
	_update_style_display()
	_refresh_preview()


func _update_style_display() -> void:
	if style_name_label:
		var idx := AVAILABLE_STYLES.find(style_id)
		var style_num := (idx + 1) if idx >= 0 else 1
		var style_name := String(STYLE_NAMES.get(style_id, "特制药瓶"))
		style_name_label.text = "瓶型：%s (%d/%d)" % [style_name, style_num, AVAILABLE_STYLES.size()]


func _refresh_preview() -> void:
	instance["bottle_style_id"] = str(style_id)
	if preview != null and potion != null:
		preview.show_instance(potion, instance)


func _on_confirm_pressed() -> void:
	if style_id == &"black":
		visible = false
		return

	var final_name := name_input.text.strip_edges() if name_input else ""
	if final_name.is_empty():
		final_name = default_potion_name if not default_potion_name.is_empty() else "特调药剂"

	confirmed.emit(style_id, final_name.left(12))
	visible = false


func _generate_default_potion_name(source_potion: PotionData, source_instance: Dictionary) -> String:
	if source_potion == null:
		return "特调药剂"

	var custom := str(source_instance.get("custom_name", "")).strip_edges()
	if not custom.is_empty():
		return custom

	var main_id := source_potion.main_effect_id
	var sec_id := StringName(str(source_instance.get("secondary_effect_id", "")))

	var base_name := ""
	match main_id:
		&"healing": base_name = "生机回春药水"
		&"attack": base_name = "狂热力量药水"
		&"speed": base_name = "疾风迅捷药水"
		&"shield": base_name = "坚毅护盾药水"
		&"mana": base_name = "凝神秘法药水"
		&"purify": base_name = "圣洁驱邪药水"
		&"concealment": base_name = "暗影迷雾药水"
		&"lightning_meteor": base_name = "雷陨天灾秘药"
		_:
			if not source_potion.display_name.is_empty():
				base_name = source_potion.display_name
			else:
				base_name = "特调魔药"

	if not sec_id.is_empty() and sec_id != main_id:
		var prefix := ""
		match sec_id:
			&"speed": prefix = "轻灵·"
			&"healing": prefix = "滋养·"
			&"shield": prefix = "坚韧·"
			&"mana": prefix = "灵感·"
			&"attack": prefix = "烈性·"
			&"purify": prefix = "澄澈·"
			&"concealment": prefix = "隐秘·"
			_: prefix = ""
		return (prefix + base_name).left(12)

	return base_name.left(12)


func _quality_name(value: float) -> String:
	if value >= 1.25:
		return "卓越"
	if value >= 0.9:
		return "良好"
	if value >= 0.6:
		return "普通"
	return "粗劣"
