class_name MenuUI
extends Control

signal start_requested
signal continue_requested
signal settings_requested
signal quit_requested
signal previous_profile_requested
signal next_profile_requested

@onready var title_group: VBoxContainer = %TitleGroup
@onready var continue_button: Button = %ContinueButton
@onready var start_button: Button = %StartButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton
@onready var debug_profiles: HBoxContainer = %DebugProfiles
@onready var profile_label: Label = %ProfileLabel

var _float_tween: Tween


func _ready() -> void:
	continue_button.pressed.connect(continue_requested.emit)
	start_button.pressed.connect(start_requested.emit)
	settings_button.pressed.connect(settings_requested.emit)
	quit_button.pressed.connect(quit_requested.emit)
	%PreviousProfileButton.pressed.connect(previous_profile_requested.emit)
	%NextProfileButton.pressed.connect(next_profile_requested.emit)
	debug_profiles.visible = OS.is_debug_build()
	_start_title_float()


func configure(has_save: bool, day: int, profile_name: String) -> void:
	continue_button.disabled = not has_save
	continue_button.tooltip_text = "读取第 %d 天存档" % day if has_save else "尚无存档"
	profile_label.text = profile_name
	if has_save:
		continue_button.grab_focus()
	else:
		start_button.grab_focus()


func set_menu_enabled(enabled: bool) -> void:
	for button: Button in [continue_button, start_button, settings_button, quit_button]:
		button.disabled = not enabled or button == continue_button and continue_button.tooltip_text == "尚无存档"
	debug_profiles.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


func fade_out() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(title_group, "modulate:a", 0.0, 0.46).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(%MenuButtons, "modulate:a", 0.0, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(debug_profiles, "modulate:a", 0.0, 0.25)


func set_profile_name(value: String) -> void:
	profile_label.text = value


func _start_title_float() -> void:
	_float_tween = create_tween().set_loops()
	_float_tween.tween_property(title_group, "position:y", title_group.position.y - 5.0, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_float_tween.tween_property(title_group, "position:y", title_group.position.y, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
