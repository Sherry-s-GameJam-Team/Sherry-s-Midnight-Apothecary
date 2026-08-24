class_name SpectrumMatrixView
extends Control

signal matrix_cell_selected(row: int, col: int, recipes: Array[PotionRecipeDefinition])

var catalog_ref: PotionSpectrumCatalog = null
var unlock_state_ref: PotionSpectrumUnlockState = null
var cell_items: Dictionary = {} # Vector2i -> MatrixCellItem
var selected_coord: Vector2i = Vector2i(-1, -1)

const MATRIX_CELL_SCENE := preload("res://night/ui/spectrum_codex/scenes/matrix_cell_item.tscn")

@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var grid_container: GridContainer = $ScrollContainer/Margin/GridContainer


func setup(catalog: PotionSpectrumCatalog, unlock_state: PotionSpectrumUnlockState) -> void:
	catalog_ref = catalog
	unlock_state_ref = unlock_state
	_build_matrix()


func refresh() -> void:
	if catalog_ref != null:
		_build_matrix()


func select_cell(row: int, col: int) -> void:
	var coord := Vector2i(row, col)
	_on_cell_clicked(coord, catalog_ref.get_recipes_for_matrix_cell(row, col) if catalog_ref else [])


func _build_matrix() -> void:
	if grid_container == null or catalog_ref == null:
		return

	for child in grid_container.get_children():
		child.queue_free()
	cell_items.clear()

	var row_labels: Array[String] = catalog_ref.matrix_row_labels
	var col_labels: Array[String] = catalog_ref.matrix_col_labels
	var rows_count: int = row_labels.size()
	var cols_count: int = col_labels.size()

	if rows_count == 0 or cols_count == 0:
		return

	grid_container.columns = cols_count + 1

	# Top-left corner cell
	var corner_label := Label.new()
	corner_label.text = "主 \\ 副"
	corner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	corner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	corner_label.custom_minimum_size = Vector2(80, 36)
	corner_label.add_theme_color_override("font_color", Color(0.48, 0.35, 0.2, 1.0))
	grid_container.add_child(corner_label)

	# Column headers
	for col_idx in range(cols_count):
		var col_header := PanelContainer.new()
		col_header.custom_minimum_size = Vector2(90, 36)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.88, 0.82, 0.7, 0.95)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.58, 0.44, 0.28, 0.8)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		col_header.add_theme_stylebox_override("panel", style)

		var lbl := Label.new()
		lbl.text = col_labels[col_idx]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", Color(0.35, 0.22, 0.1, 1.0))
		lbl.add_theme_font_size_override("font_size", 12)
		col_header.add_child(lbl)
		grid_container.add_child(col_header)

	# Rows
	for row_idx in range(rows_count):
		# Row Header
		var row_header := PanelContainer.new()
		row_header.custom_minimum_size = Vector2(100, 54)
		var r_style := StyleBoxFlat.new()
		r_style.bg_color = Color(0.88, 0.82, 0.7, 0.95)
		r_style.border_width_left = 1
		r_style.border_width_top = 1
		r_style.border_width_right = 1
		r_style.border_width_bottom = 1
		r_style.border_color = Color(0.58, 0.44, 0.28, 0.8)
		r_style.corner_radius_top_left = 4
		r_style.corner_radius_top_right = 4
		r_style.corner_radius_bottom_left = 4
		r_style.corner_radius_bottom_right = 4
		row_header.add_theme_stylebox_override("panel", r_style)

		var r_lbl := Label.new()
		r_lbl.text = row_labels[row_idx]
		r_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		r_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		r_lbl.add_theme_color_override("font_color", Color(0.35, 0.22, 0.1, 1.0))
		r_lbl.add_theme_font_size_override("font_size", 12)
		row_header.add_child(r_lbl)
		grid_container.add_child(row_header)

		# Row Cells
		for col_idx in range(cols_count):
			var coord := Vector2i(row_idx, col_idx)
			var cell := MATRIX_CELL_SCENE.instantiate() as MatrixCellItem
			grid_container.add_child(cell)
			var recipes_in_cell: Array[PotionRecipeDefinition] = catalog_ref.get_recipes_for_matrix_cell(row_idx, col_idx)
			cell.setup(coord, recipes_in_cell, unlock_state_ref, catalog_ref.get_effect_combination_at(row_idx, col_idx))
			cell.cell_clicked.connect(_on_cell_clicked)
			cell_items[coord] = cell


func _on_cell_clicked(coord: Vector2i, recipes: Array[PotionRecipeDefinition]) -> void:
	selected_coord = coord
	for c_coord: Vector2i in cell_items:
		var item: MatrixCellItem = cell_items[c_coord]
		item.set_selected(c_coord == coord)
	matrix_cell_selected.emit(coord.x, coord.y, recipes)
