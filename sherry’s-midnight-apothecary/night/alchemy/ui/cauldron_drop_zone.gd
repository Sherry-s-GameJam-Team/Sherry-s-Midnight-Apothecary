class_name CauldronDropZone
extends PanelContainer

signal ingredient_dropped(ingredient: ProcessedIngredient)
signal powder_dropped(instance_id: StringName)

@export var art_mode := false

var _count_label: Label


func _ready() -> void:
	var column := VBoxContainer.new()
	var title := Label.new()
	title.text = "炼药锅"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.visible = not art_mode
	_count_label = Label.new()
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_count_label.add_theme_color_override("font_color", Color("#f0deb6"))
	_count_label.add_theme_color_override("font_shadow_color", Color("#20150e"))
	_count_label.add_theme_constant_override("shadow_offset_x", 2)
	_count_label.add_theme_constant_override("shadow_offset_y", 2)
	column.add_child(title)
	column.add_spacer(false)
	column.add_child(_count_label)
	add_child(column)
	show_count(0)


func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	if data is not Dictionary:
		return false
	return (
		(data.get("kind") == &"processed_ingredient" and data.get("ingredient") is ProcessedIngredient)
		or (data.get("kind") == &"powder" and not str(data.get("instance_id", "")).is_empty())
	)


func _drop_data(_position: Vector2, data: Variant) -> void:
	if data.get("kind") == &"powder":
		powder_dropped.emit(StringName(str(data.get("instance_id", ""))))
	else:
		ingredient_dropped.emit(data.get("ingredient"))


func show_count(count: int) -> void:
	if _count_label != null:
		_count_label.text = "锅中材料：%d" % count if art_mode else "已加入 %d 份材料\n将处理台输出拖到这里" % count
		_count_label.visible = not art_mode or count > 0
