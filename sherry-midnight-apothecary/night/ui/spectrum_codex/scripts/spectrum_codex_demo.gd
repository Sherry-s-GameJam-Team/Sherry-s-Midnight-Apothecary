class_name SpectrumCodexDemo
extends Control

@onready var panel: SpectrumCodexPanel = $SpectrumCodexPanel
@onready var test_btn_unlock_func: Button = $DebugControls/HBox/BtnUnlockFunc
@onready var test_btn_unlock_rec: Button = $DebugControls/HBox/BtnUnlockRec
@onready var test_btn_switch_mode: Button = $DebugControls/HBox/BtnSwitchMode
@onready var test_btn_focus_sample: Button = $DebugControls/HBox/BtnFocusSample


func _ready() -> void:
	if test_btn_unlock_func:
		test_btn_unlock_func.pressed.connect(_on_unlock_test_func)
	if test_btn_unlock_rec:
		test_btn_unlock_rec.pressed.connect(_on_unlock_test_rec)
	if test_btn_switch_mode:
		test_btn_switch_mode.pressed.connect(_on_switch_mode)
	if test_btn_focus_sample:
		test_btn_focus_sample.pressed.connect(_on_focus_sample)
	if panel:
		panel.request_close.connect(_on_panel_close)


func _on_unlock_test_func() -> void:
	if panel:
		panel.unlock_function(&"func_analgesia")


func _on_unlock_test_rec() -> void:
	if panel:
		panel.unlock_recipe(&"recipe_numb_drop")


func _on_switch_mode() -> void:
	if panel:
		if panel.current_view_mode == SpectrumCodexPanel.ViewMode.VERTICAL:
			panel.set_view_mode(&"matrix")
		else:
			panel.set_view_mode(&"vertical")


func _on_focus_sample() -> void:
	if panel:
		panel.focus_recipe(&"recipe_deep_clot")


func _on_panel_close() -> void:
	print("SpectrumCodexPanel closed request received.")
