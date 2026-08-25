class_name CrownlandGardenLevel
extends DayLevelEnvironment

## Day 6 Crownland royal garden scene — King walks with Sherry and Enzo.
## Shows normal uncorrupted garden initially, dialogues with the King,
## triggers life drainage and corruption of the garden, then transitions to boss.

signal garden_dialogue_finished

const BALLOON_SCENE := preload("res://night/dialogue/apothecary_balloon.tscn")
const GARDEN_DIALOGUE := preload("res://day/levels/crownland/garden.dialogue")
const BOSS_SCENE_PATH := "res://day/levels/crownland/boss.tscn"
const DialoguePortraitDatabase := preload("res://night/dialogue/portrait_database.gd")

const TASK_ID: StringName = &"crownland_final_invitation"
const REQUIRED_DAY := 6

@export var start_dialogue_on_ready := true

@onready var normal_sky: CanvasItem = $Backdrop/FS/NormalSky
@onready var corrupted_sky: CanvasItem = $Backdrop/FS/CorruptedSky
@onready var normal_garden: CanvasItem = $Backdrop/CS/NormalGarden
@onready var corrupted_garden: CanvasItem = $Backdrop/CS/CorruptedGarden
@onready var pillars_node: Node2D = $Backdrop/Pillars
@onready var exit_barrier: CanvasItem = $Backdrop/ExitBarrier

@onready var flash_overlay: ColorRect = $Overlay/FlashOverlay
@onready var pulse_veil: ColorRect = $Overlay/PulseVeil
@onready var task_panel: PanelContainer = $Overlay/TaskPanel
@onready var task_label: RichTextLabel = $Overlay/TaskPanel/MarginContainer/TaskLabel
@onready var camera: Camera2D = $Camera2D

var _transitioning := false
var _shake_strength := 0.0
var _shake_tween: Tween
var _current_balloon: Node


func _ready() -> void:
	super._ready()
	_update_visual_state()
	DialoguePortraitDatabase.register_portrait("国王", "default", "res://characters/king/stand.png")
	DialoguePortraitDatabase.register_portrait("king", "default", "res://characters/king/stand.png")
	
	if start_dialogue_on_ready:
		call_deferred("_start_garden_dialogue")


func set_corrupted(corrupted: bool) -> void:
	super.set_corrupted(corrupted)
	_update_visual_state()


func _update_visual_state() -> void:
	var corrupted := is_corrupted()
	var n_sky := _get_normal_sky()
	var c_sky := _get_corrupted_sky()
	var n_garden := _get_normal_garden()
	var c_garden := _get_corrupted_garden()
	
	if n_sky != null:
		n_sky.visible = not corrupted
	if c_sky != null:
		c_sky.visible = corrupted
	if n_garden != null:
		n_garden.visible = not corrupted
	if c_garden != null:
		c_garden.visible = corrupted


func _get_normal_sky() -> CanvasItem:
	return normal_sky if normal_sky != null else get_node_or_null("Backdrop/FS/NormalSky") as CanvasItem


func _get_corrupted_sky() -> CanvasItem:
	return corrupted_sky if corrupted_sky != null else get_node_or_null("Backdrop/FS/CorruptedSky") as CanvasItem


func _get_normal_garden() -> CanvasItem:
	return normal_garden if normal_garden != null else get_node_or_null("Backdrop/CS/NormalGarden") as CanvasItem


func _get_corrupted_garden() -> CanvasItem:
	return corrupted_garden if corrupted_garden != null else get_node_or_null("Backdrop/CS/CorruptedGarden") as CanvasItem


func _process(delta: float) -> void:
	if _shake_strength > 0.0:
		camera.offset = Vector2(
			randf_range(-_shake_strength, _shake_strength),
			randf_range(-_shake_strength, _shake_strength)
		)
		_shake_strength = move_toward(_shake_strength, 0.0, delta * 30.0)
	else:
		camera.offset = Vector2.ZERO


func _setup_initial_visuals() -> void:
	if normal_sky != null:
		normal_sky.visible = true
		normal_sky.modulate.a = 1.0
	if corrupted_sky != null:
		corrupted_sky.visible = false
		corrupted_sky.modulate.a = 0.0
	if normal_garden != null:
		normal_garden.visible = true
		normal_garden.modulate.a = 1.0
	if corrupted_garden != null:
		corrupted_garden.visible = false
		corrupted_garden.modulate.a = 0.0
	if exit_barrier != null:
		exit_barrier.visible = false
		exit_barrier.modulate.a = 0.0
	if flash_overlay != null:
		flash_overlay.color = Color(1, 1, 1, 0)
	if pulse_veil != null:
		pulse_veil.color = Color(0.12, 0.02, 0.05, 0)
	if task_panel != null:
		task_panel.visible = false
		task_panel.modulate.a = 0.0


func _start_garden_dialogue() -> void:
	var manager := get_node_or_null("/root/DialogueManager") as Node
	if manager == null or not manager.has_method("show_dialogue_balloon_scene"):
		push_error("CrownlandGardenLevel requires DialogueManager autoload.")
		return
	
	_current_balloon = manager.show_dialogue_balloon_scene(BALLOON_SCENE, GARDEN_DIALOGUE, "king_garden_start") as Node
	if _current_balloon != null:
		if _current_balloon.has_signal("dialogue_event"):
			_current_balloon.connect("dialogue_event", Callable(self, "_on_dialogue_event"))
		_current_balloon.tree_exited.connect(_on_balloon_closed)


func _on_dialogue_event(event_name: StringName, _payload: Variant) -> void:
	match event_name:
		&"pillar_glow_gold":
			_play_pillar_gold_glow()
		&"drain_garden_life":
			_play_pillar_drain_pulse()
		&"corrupt_garden_transform":
			_play_garden_corruption()
		&"break_illusion_shatter":
			_play_illusion_break()
		&"lock_garden_exit":
			_play_lock_exit()
		&"corridor_walk_start":
			_show_task_update()
		&"corridor_heartbeat":
			_play_heartbeat_pulse()
		&"enter_throne_room":
			_play_enter_throne_room()
		&"trigger_boss_battle":
			_transition_to_boss()


func _on_balloon_closed() -> void:
	garden_dialogue_finished.emit()
	if not _transitioning:
		_transition_to_boss()


func _play_pillar_gold_glow() -> void:
	if pillars_node == null:
		return
	var tween := create_tween()
	tween.tween_property(pillars_node, "modulate", Color(1.4, 1.3, 0.95), 0.6)
	tween.tween_property(pillars_node, "modulate", Color(1.0, 1.0, 1.0), 0.8)


func _play_pillar_drain_pulse() -> void:
	_trigger_shake(8.0)
	if pillars_node != null:
		var tween := create_tween()
		tween.tween_property(pillars_node, "modulate", Color(1.8, 0.35, 0.45), 0.5)
		tween.tween_property(pillars_node, "modulate", Color(1.2, 0.5, 0.6), 0.8)
	
	if pulse_veil != null:
		var veil_tween := create_tween()
		veil_tween.tween_property(pulse_veil, "color", Color(0.3, 0.02, 0.08, 0.35), 0.4)
		veil_tween.tween_property(pulse_veil, "color", Color(0.12, 0.02, 0.05, 0.12), 0.6)


func _play_garden_corruption() -> void:
	_trigger_shake(12.0)
	var n_garden := _get_normal_garden()
	var c_garden := _get_corrupted_garden()
	if c_garden != null and n_garden != null:
		c_garden.visible = true
		if is_inside_tree():
			var tween := create_tween().set_parallel(true)
			tween.tween_property(n_garden, "modulate:a", 0.0, 1.2)
			tween.tween_property(c_garden, "modulate:a", 1.0, 1.2)
		else:
			n_garden.modulate.a = 0.0
			c_garden.modulate.a = 1.0


func _play_illusion_break() -> void:
	_trigger_shake(20.0)
	var flash := flash_overlay if flash_overlay != null else get_node_or_null("Overlay/FlashOverlay") as ColorRect
	if flash != null and is_inside_tree():
		flash.color = Color(1.0, 0.95, 0.98, 0.9)
		var flash_tween := create_tween()
		flash_tween.tween_property(flash, "color:a", 0.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	set_corrupted(true)


func _play_lock_exit() -> void:
	if exit_barrier != null:
		exit_barrier.visible = true
		var tween := create_tween()
		tween.tween_property(exit_barrier, "modulate:a", 1.0, 0.5)


func _show_task_update() -> void:
	var data := get_player_data()
	if data != null:
		data.set_active_daily_task(TASK_ID, "跟随国王前往王座之间。", REQUIRED_DAY)
	
	if task_panel != null and task_label != null:
		task_label.text = "[color=#c9b7a5]主线任务：最后的邀请[/color]\n跟随国王前往王座之间。"
		task_panel.visible = true
		var tween := create_tween()
		tween.tween_property(task_panel, "modulate:a", 1.0, 0.4)
		tween.tween_interval(3.0)
		tween.tween_property(task_panel, "modulate:a", 0.0, 0.6)
		tween.tween_callback(func(): task_panel.visible = false)


func _play_heartbeat_pulse() -> void:
	_trigger_shake(4.0)
	if pulse_veil != null:
		var tween := create_tween()
		tween.tween_property(pulse_veil, "color", Color(0.25, 0.02, 0.05, 0.4), 0.15)
		tween.tween_property(pulse_veil, "color", Color(0.12, 0.02, 0.05, 0.08), 0.45)


func _play_enter_throne_room() -> void:
	if flash_overlay != null:
		flash_overlay.color = Color(0, 0, 0, 0)
		var tween := create_tween()
		tween.tween_property(flash_overlay, "color:a", 1.0, 0.8)


func _trigger_shake(amount: float) -> void:
	_shake_strength = maxf(_shake_strength, amount)


func _transition_to_boss() -> void:
	if _transitioning:
		return
	_transitioning = true
	
	var data := get_player_data()
	if data != null:
		data.set_event_flag(&"king_garden_confrontation_complete")
	
	if flash_overlay != null:
		var tween := create_tween()
		tween.tween_property(flash_overlay, "color", Color.BLACK, 0.5)
		await tween.finished
	
	var runtime := _find_runtime()
	if runtime != null and runtime.has_method("change_level"):
		runtime.call("change_level", &"crownland_boss", &"default")
	else:
		get_tree().change_scene_to_file(BOSS_SCENE_PATH)


func _find_runtime() -> DayRuntime:
	var current := get_parent()
	while current != null:
		if current is DayRuntime:
			return current as DayRuntime
		current = current.get_parent()
	return null
