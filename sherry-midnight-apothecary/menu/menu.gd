class_name MenuController
extends Node

signal runtime_swap_requested(continue_game: bool)
signal settings_requested
signal intro_finished

enum MenuState {
	IDLE,
	TRANSITIONING,
	LOADING,
	BEDROOM_INTRO,
	FINISHED,
}

@onready var world: Node2D = %World
@onready var menu_ui: MenuUI = %MenuUI
@onready var sky_controller: MenuSkyController = %SkyController
@onready var profile_resolver: SkyProfileResolver = %SkyProfileResolver
@onready var camera_director: MenuCameraDirector = %MenuCameraDirector
@onready var silhouette_director: MenuSilhouetteDirector = %MenuSilhouetteDirector
@onready var transition_director: MenuTransitionDirector = %MenuTransitionDirector
@onready var bedroom_bridge: BedroomIntroBridge = %BedroomIntroBridge

var state := MenuState.IDLE
var selected_day := 1
var selected_mode := GameFlow.Mode.DAY
var _profile_index := 0


func _ready() -> void:
	menu_ui.start_requested.connect(_begin_transition.bind(false))
	menu_ui.continue_requested.connect(_begin_transition.bind(true))
	menu_ui.settings_requested.connect(settings_requested.emit)
	menu_ui.quit_requested.connect(get_tree().quit)
	menu_ui.previous_profile_requested.connect(_preview_relative_profile.bind(-1))
	menu_ui.next_profile_requested.connect(_preview_relative_profile.bind(1))


func configure(save_data: Dictionary) -> void:
	var has_save := not save_data.is_empty()
	selected_day = maxi(int(save_data.get("day", 1)), 1)
	var saved_mode := int(save_data.get("mode", GameFlow.Mode.DAY))
	selected_mode = saved_mode as GameFlow.Mode if GameFlow.Mode.values().has(saved_mode) else GameFlow.Mode.DAY
	var profile := profile_resolver.get_profile_for_menu(has_save, selected_mode)
	if profile != null:
		sky_controller.apply_profile(profile)
		_profile_index = maxi(profile_resolver.get_profile_index(profile), 0)
	menu_ui.configure(has_save, selected_day, profile.display_name if profile != null else "No Profile")


func runtime_loaded(runtime: Node, mode: GameFlow.Mode, day: int) -> void:
	if state != MenuState.LOADING:
		return
	world.visible = false
	camera_director.release_camera()
	var has_bedroom_intro := mode == GameFlow.Mode.DAY and runtime is DayRuntime
	if has_bedroom_intro:
		state = MenuState.BEDROOM_INTRO
		(runtime as DayRuntime).set_intro_locked(true)
		# Start the actual Bedroom wake animation while the roof reveals the
		# runtime. This masks post-instantiation hitches without duplicate art.
		bedroom_bridge.run(runtime)
	transition_director.reveal_runtime()
	await transition_director.reveal_finished
	if has_bedroom_intro and not bedroom_bridge.is_finished:
		await bedroom_bridge.finished
	if has_bedroom_intro:
		(runtime as DayRuntime).set_intro_locked(false)
	state = MenuState.FINISHED
	intro_finished.emit()


func fail_transition(message: String) -> void:
	push_error(message)
	state = MenuState.IDLE
	world.visible = true
	silhouette_director.reset()
	menu_ui.modulate.a = 1.0
	menu_ui.set_menu_enabled(true)


func _begin_transition(continue_game: bool) -> void:
	if state != MenuState.IDLE:
		return
	state = MenuState.TRANSITIONING
	menu_ui.set_menu_enabled(false)
	menu_ui.fade_out()
	transition_director.play_shadow()
	silhouette_director.play()
	camera_director.play_descent()
	await camera_director.descent_finished
	state = MenuState.LOADING
	transition_director.cover_with_roof()
	await transition_director.fully_covered
	runtime_swap_requested.emit(continue_game)


func _preview_relative_profile(direction: int) -> void:
	if not OS.is_debug_build() or state != MenuState.IDLE or profile_resolver.profiles.is_empty():
		return
	_profile_index = posmod(_profile_index + direction, profile_resolver.profiles.size())
	var profile := profile_resolver.profiles[_profile_index]
	sky_controller.apply_profile(profile)
	menu_ui.set_profile_name(profile.display_name)
