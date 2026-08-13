class_name SaleFeedback
extends PanelContainer

@onready var label: Label = %Label
var tween: Tween

func flash(message: String, success: bool) -> void:
	label.text = ("✓ " if success else "! ") + message
	modulate.a = 1.0
	visible = true
	if tween and tween.is_valid():
		tween.kill()
	tween = create_tween()
	tween.tween_interval(0.75)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func(): visible = false)
