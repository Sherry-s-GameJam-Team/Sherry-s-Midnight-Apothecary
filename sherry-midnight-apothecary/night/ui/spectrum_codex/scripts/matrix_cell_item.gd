class_name MatrixCellItem
extends Button

signal cell_clicked(coord: Vector2i, recipes: Array[PotionRecipeDefinition])

var cell_coord: Vector2i = Vector2i.ZERO
var cell_recipes: Array[PotionRecipeDefinition] = []
var effect_combination: PotionEffectCombination
var unlocked_count: int = 0
var total_count: int = 0

@onready var label_title: Label = $VBox/TitleLabel
@onready var label_count: Label = $VBox/CountLabel


func _ready() -> void:
	pressed.connect(_on_pressed)
	_update_display()


func setup(coord: Vector2i, recipes: Array[PotionRecipeDefinition], unlock_state: PotionSpectrumUnlockState, combination: PotionEffectCombination = null) -> void:
	cell_coord = coord
	cell_recipes = recipes
	effect_combination = combination
	total_count = maxi(recipes.size(), 1 if combination != null else 0)
	unlocked_count = 0

	for r in recipes:
		if unlock_state and (unlock_state.is_recipe_unlocked(r.id) or unlock_state.is_matrix_cell_unlocked(coord)):
			unlocked_count += 1
	if recipes.is_empty() and combination != null and unlock_state != null and unlock_state.is_matrix_cell_unlocked(coord):
		unlocked_count = 1

	if is_node_ready():
		_update_display()


func set_selected(selected: bool) -> void:
	if selected:
		add_theme_color_override("font_color", Color(0.72, 0.22, 0.12, 1.0))
	else:
		remove_theme_color_override("font_color")


func _update_display() -> void:
	if total_count == 0:
		if label_title:
			label_title.text = "—"
			label_title.add_theme_color_override("font_color", Color(0.65, 0.58, 0.48, 0.6))
		if label_count:
			label_count.text = "无药方"
			label_count.add_theme_color_override("font_color", Color(0.65, 0.58, 0.48, 0.6))
		tooltip_text = "该组合暂无药方"
		disabled = false
		return

	if unlocked_count == 0:
		if label_title:
			label_title.text = "🔒 未知组合"
			label_title.add_theme_color_override("font_color", Color(0.55, 0.42, 0.3, 0.8))
		if label_count:
			label_count.text = "未解锁 (0/%d)" % total_count
			label_count.add_theme_color_override("font_color", Color(0.6, 0.48, 0.35, 0.75))
		tooltip_text = "包含 %d 个未解锁药方" % total_count
	elif unlocked_count < total_count:
		if label_title:
			label_title.text = "◈ 部分发现"
			label_title.add_theme_color_override("font_color", Color(0.2, 0.45, 0.65, 1.0))
		if label_count:
			label_count.text = "%d / %d" % [unlocked_count, total_count]
			label_count.add_theme_color_override("font_color", Color(0.25, 0.48, 0.68, 0.9))
		tooltip_text = "已发现 %d / %d 个药方" % [unlocked_count, total_count]
	else:
		if label_title:
			label_title.text = effect_combination.display_name if effect_combination != null else "★ 完全掌握"
			label_title.add_theme_color_override("font_color", Color(0.72, 0.22, 0.12, 1.0))
		if label_count:
			label_count.text = "%d / %d" % [unlocked_count, total_count]
			label_count.add_theme_color_override("font_color", Color(0.55, 0.35, 0.15, 1.0))
		tooltip_text = effect_combination.description if effect_combination != null else "已解锁全部 %d 个药方" % total_count


func _on_pressed() -> void:
	cell_clicked.emit(cell_coord, cell_recipes)
