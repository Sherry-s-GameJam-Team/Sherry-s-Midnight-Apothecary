class_name SpectrumBandItem
extends PanelContainer

signal band_clicked(band: PotionSpectrumBand)
signal function_clicked(function: PotionFunctionDefinition)
signal recipe_clicked(recipe: PotionRecipeDefinition)

var band_data: PotionSpectrumBand = null
var function_items: Array[SpectrumFunctionItem] = []

const FUNCTION_ITEM_SCENE := preload("res://night/ui/spectrum_codex/scenes/spectrum_function_item.tscn")

@onready var header_button: Button = $VBox/HeaderButton
@onready var color_bar: ColorRect = $VBox/HeaderButton/HBox/ColorBar
@onready var label_name: Label = $VBox/HeaderButton/HBox/NameLabel
@onready var label_effect: Label = $VBox/HeaderButton/HBox/EffectLabel
@onready var indent_margin: MarginContainer = $VBox/IndentMargin
@onready var functions_box: VBoxContainer = $VBox/IndentMargin/FunctionsContainer


func _ready() -> void:
	if header_button:
		header_button.pressed.connect(_on_header_pressed)
	_update_display()


func setup(band: PotionSpectrumBand, functions: Array[PotionFunctionDefinition], catalog: PotionSpectrumCatalog, unlock_state: PotionSpectrumUnlockState) -> void:
	band_data = band
	_populate_functions(functions, catalog, unlock_state)
	if is_node_ready():
		_update_display()


func _populate_functions(functions: Array[PotionFunctionDefinition], catalog: PotionSpectrumCatalog, unlock_state: PotionSpectrumUnlockState) -> void:
	for child in functions_box.get_children():
		child.queue_free()
	function_items.clear()

	for func_def in functions:
		var item := FUNCTION_ITEM_SCENE.instantiate() as SpectrumFunctionItem
		functions_box.add_child(item)
		var is_func_unlocked: bool = unlock_state.is_function_unlocked(func_def.id) if unlock_state else false
		var recipes: Array[PotionRecipeDefinition] = catalog.get_recipes_for_function(func_def.id) if catalog else []
		item.setup(func_def, is_func_unlocked, recipes, unlock_state)
		item.function_clicked.connect(func(f: PotionFunctionDefinition) -> void:
			function_clicked.emit(f)
		)
		item.recipe_clicked.connect(func(r: PotionRecipeDefinition) -> void:
			recipe_clicked.emit(r)
		)
		function_items.append(item)


func set_lod_level(lod_level: int) -> void:
	# lod_level:
	# 0 = Low zoom: Bands only (functions hidden)
	# 1 = Medium zoom: Bands + Functions (recipes hidden)
	# 2 = High zoom: Bands + Functions + Recipes
	match lod_level:
		0:
			if indent_margin:
				indent_margin.visible = false
		1:
			if indent_margin:
				indent_margin.visible = true
			for item in function_items:
				item.set_lod(false)
		2:
			if indent_margin:
				indent_margin.visible = true
			for item in function_items:
				item.set_lod(true)


func set_selected(selected: bool) -> void:
	if header_button:
		if selected:
			header_button.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		else:
			header_button.remove_theme_color_override("font_color")


func focus_function(func_id: StringName) -> bool:
	var found := false
	for item in function_items:
		if item.function_data != null and item.function_data.id == func_id:
			item.set_selected(true)
			found = true
		else:
			item.set_selected(false)
	return found


func focus_recipe(recipe_id: StringName) -> bool:
	var found := false
	for item in function_items:
		if item.focus_recipe(recipe_id):
			found = true
	return found


func _update_display() -> void:
	if band_data == null:
		return

	if color_bar:
		color_bar.color = band_data.color
	if label_name:
		label_name.text = band_data.display_name
		label_name.add_theme_color_override("font_color", band_data.color.lightened(0.2))
	if label_effect:
		label_effect.text = "主功能: %s" % band_data.primary_effect_name

	var style := get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		var custom_style := style.duplicate() as StyleBoxFlat
		custom_style.border_color = band_data.color.darkened(0.15)
		add_theme_stylebox_override("panel", custom_style)


func _on_header_pressed() -> void:
	if band_data != null:
		band_clicked.emit(band_data)
