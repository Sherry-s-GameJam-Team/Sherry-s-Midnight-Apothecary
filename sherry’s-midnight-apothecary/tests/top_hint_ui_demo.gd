extends Control

const DEMO_IMAGE: Texture2D = preload("res://night/art/ui/apothecary_banner.png")

@onready var top_hint: TopHintUI = $TopHintUI


func _ready() -> void:
	top_hint.bind_player_data(PlayerData.new())
	_show_text_hint()


func _show_text_hint() -> void:
	top_hint.clear_all()
	top_hint.push_text("这是文字提示：按 Space 可以立刻显示完整内容。", "top_hint_demo_text", 0.0)


func _show_image_hint() -> void:
	top_hint.clear_all()
	top_hint.push_image_hint("这是图片提示：按 [E] 展开或收起下方图示。", DEMO_IMAGE, "top_hint_demo_image", "演示用路线图", false, 0.0)


func _on_text_button_pressed() -> void:
	_show_text_hint()


func _on_image_button_pressed() -> void:
	_show_image_hint()
