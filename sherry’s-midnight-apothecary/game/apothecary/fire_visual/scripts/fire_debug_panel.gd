class_name FireDebugPanel
extends VBoxContainer

@export var controller: FireTemperatureController
var _readout: Label

func _ready() -> void:
	if not OS.is_debug_build():
		visible = false
		return
	if controller == null: controller = get_parent() as FireTemperatureController
	if controller == null:
		visible = false
		return
	var slider := HSlider.new()
	slider.min_value = controller.minimum_temperature
	slider.max_value = controller.maximum_temperature
	slider.value_changed.connect(controller.set_temperature)
	add_child(slider)
	for title in ["Slow heat", "Slow cool", "Random temperature"]:
		var button := Button.new(); button.text = title; add_child(button)
		if title == "Slow heat": button.pressed.connect(func(): controller.set_temperature(controller.maximum_temperature))
		elif title == "Slow cool": button.pressed.connect(func(): controller.set_temperature(controller.minimum_temperature))
		else: button.pressed.connect(func(): controller.set_normalized_temperature(randf()))
	_readout = Label.new(); add_child(_readout)

func _process(_delta: float) -> void:
	if visible and controller != null:
		_readout.text = "T %.1f / %.1f | heat %.3f | S%02d-S%02d | blend %.3f | phase %.3f | light %.2f" % [controller.current_temperature, controller.target_temperature, controller.get_normalized_heat(), controller.lower_state, controller.upper_state, controller.state_blend, controller.animation_phase, controller.fire_light.energy]
