class_name SpectrumFunctionItem
extends PanelContainer

signal function_clicked(function: PotionFunctionDefinition)
signal recipe_clicked(recipe: PotionRecipeDefinition)

var function_data: PotionFunctionDefinition = null
var is_unlocked: bool = false
var recipe_nodes: Array[SpectrumRecipeNode] = []

const RECIPE_NODE_SCENE := preload("res://night/ui/spectrum_codex/scenes/spectrum_recipe_node.tscn")

@onready var header_button: Button = $VBox/HeaderButton
@onready var label_name: Label = $VBox/HeaderButton/HBox/NameLabel
@onready var label_tags: Label = $VBox/HeaderButton/HBox/TagsLabel
@onready var lock_icon: Label = $VBox/HeaderButton/HBox/LockIcon
@onready var recipes_margin: MarginContainer = $VBox/RecipesMargin
@onready var recipes_box: Container = $VBox/RecipesMargin/RecipesContainer


func _ready() -> void:
	if header_button:
		header_button.pressed.connect(_on_header_pressed)
	_update_display()


func setup(func_def: PotionFunctionDefinition, unlocked: bool, recipes: Array[PotionRecipeDefinition], unlock_state: PotionSpectrumUnlockState) -> void:
	function_data = func_def
	is_unlocked = unlocked
	_populate_recipes(recipes, unlock_state)
	if is_node_ready():
		_update_display()


func _populate_recipes(recipes: Array[PotionRecipeDefinition], unlock_state: PotionSpectrumUnlockState) -> void:
	for child in recipes_box.get_children():
		child.queue_free()
	recipe_nodes.clear()

	for recipe in recipes:
		var node := RECIPE_NODE_SCENE.instantiate() as SpectrumRecipeNode
		recipes_box.add_child(node)
		var rec_unlocked: bool = unlock_state.is_recipe_unlocked(recipe.id) if unlock_state else false
		node.setup(recipe, rec_unlocked)
		node.recipe_clicked.connect(func(r: PotionRecipeDefinition) -> void:
			recipe_clicked.emit(r)
		)
		recipe_nodes.append(node)


func set_lod(show_recipes: bool) -> void:
	if recipes_margin:
		recipes_margin.visible = show_recipes and is_unlocked


func set_selected(selected: bool) -> void:
	if header_button:
		if selected:
			header_button.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		else:
			header_button.remove_theme_color_override("font_color")


func focus_recipe(recipe_id: StringName) -> bool:
	for node in recipe_nodes:
		if node.recipe_data != null and node.recipe_data.id == recipe_id:
			node.set_selected(true)
			return true
		else:
			node.set_selected(false)
	return false


func _update_display() -> void:
	if function_data == null:
		return

	if is_unlocked:
		if label_name:
			label_name.text = function_data.display_name
		if label_tags:
			label_tags.text = "[%s · %s]" % [function_data.primary_tag, function_data.secondary_tag]
			label_tags.visible = true
		if lock_icon:
			lock_icon.visible = false
	else:
		if label_name:
			label_name.text = "未知功能分支"
		if label_tags:
			label_tags.text = "[未解锁]"
			label_tags.visible = true
		if lock_icon:
			lock_icon.visible = true
		if recipes_margin:
			recipes_margin.visible = false


func _on_header_pressed() -> void:
	if function_data != null:
		function_clicked.emit(function_data)
