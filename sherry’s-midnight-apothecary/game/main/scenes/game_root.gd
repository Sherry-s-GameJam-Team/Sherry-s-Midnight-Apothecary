extends Node

const TOWN_SCENE := preload("res://game/main/scenes/town/town_morning.tscn")
const RAINTREE_SCENE := preload("res://game/main/scenes/raintree/raintree.tscn")
const LAKE_SCENE := preload("res://game/main/scenes/lake/lake.tscn")
const TOWN_LEVEL_DEFINITION := preload("res://game/main/data/levels/town_level.tres")
const RAINTREE_LEVEL_DEFINITION := preload("res://game/main/data/levels/raintree_level.tres")
const LAKE_LEVEL_DEFINITION := preload("res://game/main/data/levels/lake_level.tres")
const LEVEL_DEFINITIONS := {
	&"town": TOWN_LEVEL_DEFINITION,
	&"raintree": RAINTREE_LEVEL_DEFINITION,
	&"lake": LAKE_LEVEL_DEFINITION,
}
const SCENE_CAMERA_BLEND_SHADER := preload("res://game/main/scenes/transition/scene_camera_blend_transition.gdshader")
const DESTINATION_SCENES := {
	"town": TOWN_SCENE,
	"raintree": RAINTREE_SCENE,
	"lake": LAKE_SCENE,
}
const INITIAL_SCENE_KEY := "town"
const TRANSITION_DURATION := 0.72
const TRANSITION_PREWARM_FRAMES := 2
const TRANSITION_PIXEL_CELL := 2.0
const TRANSITION_SOFTNESS := 0.075
const TRANSITION_NOISE_STRENGTH := 0.18
const TRANSITION_PARTICLE_AMOUNT := 0.20
const TRANSITION_PARTICLE_BAND := 0.075
const TRANSITION_DISSOLVE_MOTION := 0.22
const TRANSITION_PARTICLE_FLICKER := 0.72

var current_scene: Node = null
var current_scene_key := ""
var is_switching := false
var transition_material: ShaderMaterial = null
var transition_progress := 0.0
var pending_old_scene: Node = null
var pending_from_scene: Node = null
var pending_next_scene: Node = null
var pending_destination_key := ""
var is_transition_previewing := false
var can_show_transition_rect := true

@onready var scene_host: Node = $SceneHost
@onready var scene_router: SceneRouter = $SceneRouter
@onready var transition_viewports: Node = $TransitionViewports
@onready var from_viewport: SubViewport = $TransitionViewports/FromViewport
@onready var to_viewport: SubViewport = $TransitionViewports/ToViewport
@onready var transition_rect: ColorRect = $TransitionLayer/TransitionRect


func _ready() -> void:
	_configure_transition_rect()
	_configure_transition_viewports()
	_setup_transition_material()
	set_transition_progress(0.0)
	_load_scene(INITIAL_SCENE_KEY, "", false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_sync_transition_viewport_size()


func _on_interior_exit_to_destination(destination_key: String) -> void:
	if scene_router != null:
		scene_router.change_level(StringName(destination_key), &"default", {})
	else:
		transition_to_destination(destination_key)


func _on_interior_transition_progress_changed(destination_key: String, progress: float) -> void:
	_update_transition_preview(destination_key, progress)


func transition_to_destination(destination_key: String) -> void:
	if is_switching:
		if is_transition_previewing and destination_key == pending_destination_key:
			set_transition_progress(1.0)
			_finish_scene_transition()
		return
	if destination_key.is_empty() or destination_key == current_scene_key:
		return

	await _switch_to_scene(destination_key, current_scene_key)


func request_level_change(target_level_id: StringName, entry_id: StringName = &"default", transition_data: Dictionary = {}) -> bool:
	if scene_router != null:
		return scene_router.change_level(target_level_id, entry_id, transition_data)
	if target_level_id.is_empty() or String(target_level_id) == current_scene_key:
		return false
	transition_to_destination(String(target_level_id))
	return true


func get_level_definition(level_id: StringName) -> LevelDefinition:
	return LEVEL_DEFINITIONS.get(level_id) as LevelDefinition


func set_transition_progress(value: float) -> void:
	transition_progress = clampf(value, 0.0, 1.0)
	if transition_material != null:
		transition_material.set_shader_parameter("progress", transition_progress)
		transition_material.set_shader_parameter("time_value", Time.get_ticks_msec() / 1000.0)
	transition_rect.visible = can_show_transition_rect and transition_progress > 0.001


func _switch_to_scene(destination_key: String, from_key: String) -> void:
	if not DESTINATION_SCENES.has(destination_key):
		push_warning("No scene registered for changer destination: %s" % destination_key)
		return
	if current_scene == null:
		_load_scene(destination_key, from_key, true)
		return

	is_switching = true
	pending_destination_key = destination_key

	var arrival_state: Dictionary = _arrival_state_for_destination(destination_key)
	var definition := get_level_definition(StringName(destination_key))
	var packed_scene := definition.scene if definition != null else DESTINATION_SCENES[destination_key] as PackedScene
	pending_old_scene = current_scene
	pending_from_scene = pending_old_scene
	pending_next_scene = packed_scene.instantiate()
	_set_scene_title_intro_enabled(pending_next_scene, false)
	_hide_scene_title_intro_artifacts(pending_old_scene)

	_prepare_dual_viewport_transition(pending_old_scene, pending_next_scene, from_key, arrival_state, false)
	for frame in TRANSITION_PREWARM_FRAMES:
		await get_tree().process_frame

	await _tween_transition_progress(1.0, TRANSITION_DURATION)
	_finish_scene_transition()


func _load_scene(scene_key: String, from_key: String, notify_arrival: bool, arrival_state: Dictionary = {}) -> void:
	var old_scene: Node = current_scene

	var definition := get_level_definition(StringName(scene_key))
	var packed_scene := definition.scene if definition != null else DESTINATION_SCENES[scene_key] as PackedScene
	var next_scene: Node = packed_scene.instantiate()
	_set_scene_title_intro_enabled(next_scene, scene_key == INITIAL_SCENE_KEY and from_key.is_empty() and not notify_arrival)
	current_scene = next_scene
	current_scene_key = scene_key
	scene_host.add_child(current_scene)
	_validate_level_contract(current_scene)
	_connect_scene_signals(current_scene)

	if notify_arrival and current_scene.has_method("prepare_for_arrival"):
		current_scene.call("prepare_for_arrival", from_key, arrival_state)

	if old_scene != null:
		old_scene.queue_free()
	if scene_router != null:
		scene_router.complete_change()


func _connect_scene_signals(scene: Node) -> void:
	if scene.has_signal("interior_exit_to_destination"):
		var callback := Callable(self, "_on_interior_exit_to_destination")
		if not scene.is_connected("interior_exit_to_destination", callback):
			scene.connect("interior_exit_to_destination", callback)
	if scene.has_signal("interior_transition_progress_changed"):
		var progress_callback := Callable(self, "_on_interior_transition_progress_changed")
		if not scene.is_connected("interior_transition_progress_changed", progress_callback):
			scene.connect("interior_transition_progress_changed", progress_callback)


func _arrival_state_for_destination(destination_key: String) -> Dictionary:
	if current_scene == null:
		return {}
	if not current_scene.has_method("get_interior_transition_state"):
		return {}

	var state = current_scene.call("get_interior_transition_state", destination_key)
	if state is Dictionary:
		return state as Dictionary
	return {}


func _update_transition_preview(destination_key: String, progress: float) -> void:
	var clamped_progress := clampf(progress, 0.0, 1.0)
	if destination_key.is_empty() or clamped_progress <= 0.001:
		if is_transition_previewing:
			_cancel_transition_preview()
		return
	if destination_key == current_scene_key:
		return
	if not DESTINATION_SCENES.has(destination_key):
		return

	if not is_transition_previewing:
		if is_switching:
			return
		_begin_transition_preview(destination_key)

	if is_transition_previewing and destination_key == pending_destination_key:
		set_transition_progress(clamped_progress)


func _begin_transition_preview(destination_key: String) -> void:
	if current_scene == null:
		return

	is_switching = true
	is_transition_previewing = true
	can_show_transition_rect = false
	pending_destination_key = destination_key

	var arrival_state: Dictionary = _arrival_state_for_destination(destination_key)
	var definition := get_level_definition(StringName(destination_key))
	var current_definition := get_level_definition(StringName(current_scene_key))
	var packed_scene := definition.scene if definition != null else DESTINATION_SCENES[destination_key] as PackedScene
	var current_packed_scene := current_definition.scene if current_definition != null else DESTINATION_SCENES[current_scene_key] as PackedScene
	pending_old_scene = current_scene
	pending_from_scene = current_packed_scene.instantiate()
	pending_next_scene = packed_scene.instantiate()
	_set_scene_title_intro_enabled(pending_from_scene, false)
	_set_scene_title_intro_enabled(pending_next_scene, false)
	_strip_preview_only_nodes(pending_from_scene)
	_hide_scene_title_intro_artifacts(pending_from_scene)

	_prepare_dual_viewport_transition(pending_from_scene, pending_next_scene, current_scene_key, arrival_state, true)
	_enable_preview_rect_after_prewarm()


func _prepare_dual_viewport_transition(old_scene: Node, next_scene: Node, from_key: String, arrival_state: Dictionary, keep_current_scene_in_host: bool) -> void:
	_sync_transition_viewport_size()
	_set_transition_viewports_enabled(true)
	_clear_transition_viewport(from_viewport)
	_clear_transition_viewport(to_viewport)

	if keep_current_scene_in_host:
		from_viewport.add_child(old_scene)
	else:
		_move_child_to_parent(old_scene, from_viewport)
	if keep_current_scene_in_host and old_scene.has_method("prepare_transition_preview_from"):
		old_scene.call("prepare_transition_preview_from", current_scene)
	to_viewport.add_child(next_scene)
	_connect_scene_signals(next_scene)
	if next_scene.has_method("prepare_for_arrival"):
		next_scene.call("prepare_for_arrival", from_key, arrival_state)
	if keep_current_scene_in_host:
		_set_scene_player_input_locked(old_scene, true)
		_set_scene_player_input_locked(next_scene, true)

	_setup_transition_material()
	transition_material.set_shader_parameter("tex_from", from_viewport.get_texture())
	transition_material.set_shader_parameter("tex_to", to_viewport.get_texture())
	transition_material.set_shader_parameter("seed", _transition_seed(from_key, pending_destination_key))
	transition_rect.material = transition_material
	set_transition_progress(0.0)
	if not keep_current_scene_in_host:
		can_show_transition_rect = true
		transition_rect.visible = true


func _finish_scene_transition() -> void:
	set_transition_progress(1.0)
	if transition_material != null:
		transition_rect.visible = true

	var old_scene := pending_old_scene
	var from_scene := pending_from_scene
	var next_scene := pending_next_scene
	var destination_key := pending_destination_key

	if old_scene != null:
		var old_parent := old_scene.get_parent()
		if old_parent != null:
			old_parent.remove_child(old_scene)

	if next_scene != null:
		_move_child_to_parent(next_scene, scene_host)
		current_scene = next_scene
		current_scene_key = destination_key
		_validate_level_contract(current_scene)
		_set_scene_player_input_locked(current_scene, false)

	if old_scene != null:
		old_scene.queue_free()
	if from_scene != null and from_scene != old_scene:
		from_scene.queue_free()

	pending_old_scene = null
	pending_from_scene = null
	pending_next_scene = null
	pending_destination_key = ""
	is_transition_previewing = false
	can_show_transition_rect = true
	set_transition_progress(0.0)
	transition_rect.visible = false
	_clear_transition_viewport(from_viewport)
	_clear_transition_viewport(to_viewport)
	_set_transition_viewports_enabled(false)
	is_switching = false
	if scene_router != null:
		scene_router.complete_change()


func _validate_level_contract(scene: Node) -> void:
	if scene == null:
		return
	var controller := scene.find_child("LevelController", true, false) as LevelController
	if controller == null:
		push_warning("Scene %s has no LevelController; retaining compatibility behavior." % scene.name)
		return
	if controller.definition == null:
		push_warning("Scene %s LevelController has no LevelDefinition." % scene.name)


func _enable_preview_rect_after_prewarm() -> void:
	for frame in TRANSITION_PREWARM_FRAMES:
		await get_tree().process_frame
	if is_transition_previewing:
		can_show_transition_rect = true
		transition_rect.visible = transition_progress > 0.001


func _cancel_transition_preview() -> void:
	if pending_next_scene != null:
		pending_next_scene.queue_free()
	if pending_from_scene != null and pending_from_scene != current_scene:
		pending_from_scene.queue_free()

	pending_old_scene = null
	pending_from_scene = null
	pending_next_scene = null
	pending_destination_key = ""
	is_transition_previewing = false
	can_show_transition_rect = true
	set_transition_progress(0.0)
	transition_rect.visible = false
	_clear_transition_viewport(from_viewport)
	_clear_transition_viewport(to_viewport)
	_set_transition_viewports_enabled(false)
	is_switching = false


func _tween_transition_progress(target_progress: float, duration: float) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(set_transition_progress, transition_progress, target_progress, duration)
	await tween.finished


func _configure_transition_rect() -> void:
	transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_rect.color = Color.WHITE
	transition_rect.visible = false


func _configure_transition_viewports() -> void:
	_sync_transition_viewport_size()
	_set_transition_viewport_options(from_viewport)
	_set_transition_viewport_options(to_viewport)
	_set_transition_viewports_enabled(false)


func _set_transition_viewport_options(viewport: SubViewport) -> void:
	viewport.transparent_bg = false
	viewport.disable_3d = true
	viewport.handle_input_locally = false
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS


func _sync_transition_viewport_size() -> void:
	if from_viewport == null or to_viewport == null:
		return

	var visible_size := get_viewport().get_visible_rect().size
	var viewport_size := Vector2i(maxi(1, int(ceil(visible_size.x))), maxi(1, int(ceil(visible_size.y))))
	from_viewport.size = viewport_size
	to_viewport.size = viewport_size
	if transition_material != null:
		transition_material.set_shader_parameter("target_size", Vector2(viewport_size))


func _set_transition_viewports_enabled(enabled: bool) -> void:
	var mode := SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_DISABLED
	if from_viewport != null:
		from_viewport.render_target_update_mode = mode
	if to_viewport != null:
		to_viewport.render_target_update_mode = mode


func _setup_transition_material() -> void:
	if transition_material == null:
		transition_material = ShaderMaterial.new()
		transition_material.shader = SCENE_CAMERA_BLEND_SHADER
	transition_material.set_shader_parameter("softness", TRANSITION_SOFTNESS)
	transition_material.set_shader_parameter("pixel_cell", TRANSITION_PIXEL_CELL)
	transition_material.set_shader_parameter("noise_strength", TRANSITION_NOISE_STRENGTH)
	transition_material.set_shader_parameter("particle_amount", TRANSITION_PARTICLE_AMOUNT)
	transition_material.set_shader_parameter("particle_band", TRANSITION_PARTICLE_BAND)
	transition_material.set_shader_parameter("dissolve_motion", TRANSITION_DISSOLVE_MOTION)
	transition_material.set_shader_parameter("particle_flicker", TRANSITION_PARTICLE_FLICKER)
	_sync_transition_viewport_size()


func _transition_seed(from_key: String, destination_key: String) -> float:
	var hash_value := 0
	var key := "%s:%s" % [from_key, destination_key]
	for character_index in key.length():
		hash_value = int(hash_value * 31 + key.unicode_at(character_index)) % 9973
	return float(hash_value) * 0.01 + 1.0


func _move_child_to_parent(child: Node, new_parent: Node) -> void:
	var old_parent := child.get_parent()
	if old_parent != null:
		old_parent.remove_child(child)
	new_parent.add_child(child)


func _strip_preview_only_nodes(root_node: Node) -> void:
	if root_node == null:
		return

	for child in root_node.get_children():
		if child.name in ["ClockMapOverlay", "HollMapOverlay", "InteractionReminderManager", "TitleMenuLayer", "TitleSleepSprite"]:
			root_node.remove_child(child)
			child.free()
			continue
		_strip_preview_only_nodes(child)


func _set_scene_player_input_locked(scene: Node, locked: bool) -> void:
	if scene == null:
		return

	var player := scene.get_node_or_null("Player")
	if player != null and player.has_method("set_input_locked"):
		player.call("set_input_locked", locked)


func _set_scene_title_intro_enabled(scene: Node, enabled: bool) -> void:
	if scene == null:
		return
	for property in scene.get_property_list():
		if String(property.get("name", "")) == "start_in_title_intro":
			scene.set("start_in_title_intro", enabled)
			return


func _hide_scene_title_intro_artifacts(scene: Node) -> void:
	if scene != null and scene.has_method("hide_title_intro_artifacts"):
		scene.call("hide_title_intro_artifacts")


func _clear_transition_viewport(viewport: SubViewport) -> void:
	if viewport == null:
		return

	for child in viewport.get_children():
		if child == pending_old_scene or child == pending_from_scene or child == pending_next_scene:
			continue
		child.queue_free()
