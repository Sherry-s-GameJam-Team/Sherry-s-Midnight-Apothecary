class_name SpectrumRecipeNode
extends Button

signal recipe_clicked(recipe: PotionRecipeDefinition)

var recipe_data: PotionRecipeDefinition = null
var is_unlocked: bool = false

@onready var icon_rect: TextureRect = $HBox/IconRect
@onready var label_name: Label = $HBox/NameLabel
@onready var special_badge: Label = $HBox/SpecialBadge
@onready var lock_icon: Label = $HBox/LockIcon


func _ready() -> void:
	pressed.connect(_on_pressed)
	_update_display()


func setup(recipe: PotionRecipeDefinition, unlocked: bool) -> void:
	recipe_data = recipe
	is_unlocked = unlocked
	if is_node_ready():
		_update_display()


func set_selected(selected: bool) -> void:
	if selected:
		add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	else:
		remove_theme_color_override("font_color")


func _update_display() -> void:
	if recipe_data == null:
		text = ""
		return

	if is_unlocked:
		if label_name:
			label_name.text = recipe_data.display_name
		if special_badge:
			special_badge.visible = recipe_data.is_special
		if lock_icon:
			lock_icon.visible = false
		if icon_rect:
			icon_rect.visible = (recipe_data.icon != null)
			if recipe_data.icon != null:
				icon_rect.texture = recipe_data.icon
		tooltip_text = recipe_data.display_name
	else:
		if label_name:
			label_name.text = "？？？"
		if special_badge:
			special_badge.visible = false
		if lock_icon:
			lock_icon.visible = true
		if icon_rect:
			icon_rect.visible = false
		tooltip_text = "未解锁药方"


func _on_pressed() -> void:
	if recipe_data != null:
		recipe_clicked.emit(recipe_data)
