extends CanvasLayer

## Standalone host for the global PauseMenu embedded in golden_cliff.tscn.
##
## Mirrors app_root._unhandled_input: B (open_backpack) opens the backpack page,
## ESC (ui_cancel) opens the pause menu (settings page by default). Player data
## is bound from the level root (DayLevelEnvironment.get_player_data()) so the
## backpack shows the same inventory the PotionThrower/hotbar use in standalone
## runs.
##
## Under DayRuntime, day_level_environment.gd disables this layer and AppRoot's
## global PauseMenu takes over (this embedded copy stays hidden and inert).

@onready var pause_menu: Node = $PauseMenu


func _ready() -> void:
	var level := get_parent()
	if level != null and level.has_method("get_player_data") and pause_menu != null and pause_menu.has_method("bind_player_data"):
		pause_menu.call("bind_player_data", level.call("get_player_data"))


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().has_meta("day_modal_input_locked"):
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit:
		return
	if pause_menu == null:
		return
	if event.is_action_pressed("open_backpack") and not pause_menu.visible:
		if pause_menu.has_method("open"):
			var page_idx: int = 2
			var scr = pause_menu.get_script()
			if scr != null and "Page" in scr.get_script_constant_map():
				page_idx = scr.get_script_constant_map()["Page"].get("BACKPACK", 2)
			pause_menu.call("open", page_idx)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and not pause_menu.visible:
		if pause_menu.has_method("open"):
			pause_menu.call("open")
		get_viewport().set_input_as_handled()
