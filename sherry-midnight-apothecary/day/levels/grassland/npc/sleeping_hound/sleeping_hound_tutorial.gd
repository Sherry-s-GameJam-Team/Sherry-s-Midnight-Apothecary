class_name SleepingHoundTutorial
extends Node

signal tutorial_started
signal tutorial_succeeded
signal tutorial_failed(reason: String)
signal purification_potion_reloaded

enum Stage {
	IDLE,
	WAIT_BACKPACK,
	SELECT_POTION,
	EQUIP_POTION,
	WAIT_RETURN,
	AIM_AND_THROW,
	RESOLVING_THROW,
	COMPLETE,
}

const PAUSE_MENU_SCENE := preload("res://night/ui/pause_menu/pause_menu.tscn")
const TOP_HINT_SCENE := preload("res://night/ui/top_hint/top_hint_ui.tscn")
const TARGET_POTION_ID := &"purification_potion"
const THROW_HINT_ID := "sleeping_hound_throw_tutorial"
const BACKPACK_HINT_ID := "sleeping_hound_backpack_tutorial"

@export var npc_path := NodePath("SleepingHoundNPC")
@export var player_path := NodePath("Player")
@export var target_offset := Vector2(0.0, -72.0)
@export_range(40.0, 300.0, 1.0) var target_radius := 145.0

var stage := Stage.IDLE
var _npc: SleepingHoundNPC
var _player: CharacterBody2D
var _thrower: PotionThrower
var _player_data: PlayerData
var _pause_menu: PauseMenu
var _inventory_page: PauseInventoryPage
var _top_hint: TopHintUI
var _task_complete_ui: TaskCompleteUI
var _owns_local_ui := false
var _equipped_slot := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_initialize")


func _unhandled_input(event: InputEvent) -> void:
	if not _owns_local_ui or stage == Stage.IDLE or stage == Stage.COMPLETE or _pause_menu == null:
		return
	if get_tree().has_meta("day_modal_input_locked"):
		return
	if not _pause_menu.visible and event.is_action_pressed("open_backpack"):
		_pause_menu.open(PauseMenu.Page.BACKPACK)
		get_viewport().set_input_as_handled()
	elif not _pause_menu.visible and event.is_action_pressed("ui_cancel"):
		_pause_menu.open(PauseMenu.Page.SETTINGS)
		get_viewport().set_input_as_handled()


func _initialize() -> void:
	var level_root := get_parent()
	_npc = level_root.get_node_or_null(npc_path) as SleepingHoundNPC
	_player = level_root.get_node_or_null(player_path) as CharacterBody2D
	_task_complete_ui = level_root.get_node_or_null("TaskCompleteUI") as TaskCompleteUI
	_thrower = _player.get_node_or_null("PotionThrower") as PotionThrower if _player != null else null
	_player_data = _find_player_data()
	if _npc == null or _player == null or _thrower == null or _player_data == null:
		push_error("SleepingHoundTutorial requires the hound, player, PotionThrower and PlayerData.")
		return
	if not _npc.is_available_this_day():
		return
	_npc.dialogue_event.connect(_on_dialogue_event)
	if bool(_player_data.tutorial_flags.get("sleeping_hound_purification_complete", false)):
		stage = Stage.COMPLETE
		_npc.set_purified_state(true)
		_npc.set_interaction_enabled(true)
		return
	_thrower.projectile_spawned.connect(_on_projectile_spawned)
	_resolve_ui()


func _on_dialogue_event(event_name: StringName, _payload: Variant) -> void:
	if event_name != &"sleeping_hound_tutorial_begin" or stage != Stage.IDLE:
		return
	begin_tutorial()


func begin_tutorial() -> void:
	if stage != Stage.IDLE and stage != Stage.COMPLETE:
		return
	_resolve_ui()
	_ensure_purification_potion()
	_npc.set_interaction_enabled(false)
	stage = Stage.WAIT_BACKPACK
	tutorial_started.emit()
	_show_persistent_hint(BACKPACK_HINT_ID, "按 B 直接打开背包，再点击净化药水并装入快捷栏。")
	if _pause_menu != null and _pause_menu.visible and _pause_menu.active_page == PauseMenu.Page.BACKPACK:
		_on_pause_page_changed(PauseMenu.Page.BACKPACK)


func _resolve_ui() -> void:
	if _pause_menu != null and _top_hint != null:
		return
	var current: Node = self
	while current != null:
		if _pause_menu == null:
			_pause_menu = current.get_node_or_null("GlobalUI/PauseMenu") as PauseMenu
		if _top_hint == null:
			_top_hint = current.get_node_or_null("GlobalUI/TopHintUI") as TopHintUI
		if _pause_menu != null and _top_hint != null:
			break
		current = current.get_parent()
	if _pause_menu == null:
		_pause_menu = get_tree().get_first_node_in_group("pause_menu") as PauseMenu
	if _top_hint == null:
		_top_hint = get_tree().root.find_child("TopHintUI", true, false) as TopHintUI
	if _pause_menu == null or _top_hint == null:
		_create_standalone_ui()
	_inventory_page = _pause_menu.inventory_page if _pause_menu != null else null
	_connect_ui_signals()


func _create_standalone_ui() -> void:
	_owns_local_ui = true
	if _top_hint == null:
		var hint_layer := CanvasLayer.new()
		hint_layer.name = "SleepingHoundHintLayer"
		hint_layer.layer = 150
		get_parent().add_child(hint_layer)
		_top_hint = TOP_HINT_SCENE.instantiate() as TopHintUI
		hint_layer.add_child(_top_hint)
		_top_hint.bind_player_data(_player_data)
	if _pause_menu == null:
		var pause_layer := CanvasLayer.new()
		pause_layer.name = "SleepingHoundPauseLayer"
		pause_layer.layer = 200
		get_parent().add_child(pause_layer)
		_pause_menu = PAUSE_MENU_SCENE.instantiate() as PauseMenu
		pause_layer.add_child(_pause_menu)
		_pause_menu.bind_player_data(_player_data)


func _connect_ui_signals() -> void:
	if _pause_menu != null:
		if not _pause_menu.page_changed.is_connected(_on_pause_page_changed):
			_pause_menu.page_changed.connect(_on_pause_page_changed)
		if not _pause_menu.resumed.is_connected(_on_pause_resumed):
			_pause_menu.resumed.connect(_on_pause_resumed)
	if _inventory_page != null:
		if not _inventory_page.potion_selected.is_connected(_on_potion_selected):
			_inventory_page.potion_selected.connect(_on_potion_selected)
		if not _inventory_page.potion_equipped.is_connected(_on_potion_equipped):
			_inventory_page.potion_equipped.connect(_on_potion_equipped)


func _on_pause_page_changed(page: PauseMenu.Page) -> void:
	if page != PauseMenu.Page.BACKPACK or stage not in [Stage.WAIT_BACKPACK, Stage.SELECT_POTION, Stage.EQUIP_POTION]:
		return
	_hide_hint(BACKPACK_HINT_ID)
	stage = Stage.SELECT_POTION
	_inventory_page.begin_potion_equip_tutorial(TARGET_POTION_ID)


func _on_potion_selected(potion_id: StringName) -> void:
	if stage != Stage.SELECT_POTION or potion_id != TARGET_POTION_ID:
		return
	stage = Stage.EQUIP_POTION


func _on_potion_equipped(slot_index: int, potion_id: StringName) -> void:
	if stage not in [Stage.SELECT_POTION, Stage.EQUIP_POTION] or potion_id != TARGET_POTION_ID:
		return
	_equipped_slot = slot_index
	_player_data.select_potion_slot(slot_index)
	stage = Stage.WAIT_RETURN


func _on_pause_resumed() -> void:
	if stage == Stage.WAIT_RETURN:
		_inventory_page.end_potion_equip_tutorial()
		_begin_throw_lesson()
	elif stage in [Stage.SELECT_POTION, Stage.EQUIP_POTION]:
		_inventory_page.end_potion_equip_tutorial()
		stage = Stage.WAIT_BACKPACK
		_show_persistent_hint(BACKPACK_HINT_ID, "净化药水还未装配，请重新打开背包完成装配。")


func _begin_throw_lesson() -> void:
	stage = Stage.AIM_AND_THROW
	_thrower.show()
	if _equipped_slot >= 0:
		_player_data.select_potion_slot(_equipped_slot)
	_npc.show_target_guide(target_offset, target_radius)
	_show_persistent_hint(THROW_HINT_ID, "按住鼠标左键向投掷反方向拖动，松开后把净化药水投进魔犬的箭头目标区。")


func _on_projectile_spawned(projectile: PotionProjectile) -> void:
	if stage != Stage.AIM_AND_THROW:
		return
	stage = Stage.RESOLVING_THROW
	projectile.broken.connect(_on_projectile_broken.bind(projectile), CONNECT_ONE_SHOT)


func _on_projectile_broken(point: Vector2, _normal: Vector2, projectile: PotionProjectile) -> void:
	if stage != Stage.RESOLVING_THROW:
		return
	var potion_id := projectile.potion.id if projectile.potion != null else &""
	var target_point := _npc.global_position + target_offset
	if potion_id == TARGET_POTION_ID and point.distance_to(target_point) <= target_radius:
		_complete_tutorial()
		return
	stage = Stage.AIM_AND_THROW
	var reason := "请使用净化药水。" if potion_id != TARGET_POTION_ID else "没有投进目标区域，请重新再来。"
	tutorial_failed.emit(reason)
	_npc.report_purification_failure(reason)
	if _player_data.potion_dose(TARGET_POTION_ID) + PotionInventoryService.DOSE_EPSILON < _thrower.throw_tuning.dose_per_throw:
		_reload_purification_potion()
	_show_persistent_hint(THROW_HINT_ID, "%s 按住左键拖动后松开，再试一次。" % reason)


func _complete_tutorial() -> void:
	stage = Stage.COMPLETE
	_hide_hint(THROW_HINT_ID)
	_npc.hide_target_guide()
	_player_data.tutorial_flags["sleeping_hound_purification_complete"] = true
	_npc.report_purification_success()
	tutorial_succeeded.emit()
	if _task_complete_ui != null:
		if not _task_complete_ui.dismissed.is_connected(_on_task_complete_dismissed):
			_task_complete_ui.dismissed.connect(_on_task_complete_dismissed, CONNECT_ONE_SHOT)
		_task_complete_ui.present(
			"魔化猎犬的净化",
			"瘴气已经消散，快去看看它具体情况吧。",
			"净化教程已完成 · 任务进度已记录"
		)
	elif _top_hint != null:
		_top_hint.push_text("净化成功！魔犬身上的侵蚀正在消退。", "sleeping_hound_success", 5.0)
	else:
		_npc.set_interaction_enabled(true)


func _on_task_complete_dismissed() -> void:
	_npc.set_interaction_enabled(true)


func _ensure_purification_potion() -> void:
	if _player_data.potion_dose(TARGET_POTION_ID) + PotionInventoryService.DOSE_EPSILON >= _thrower.throw_tuning.dose_per_throw:
		return
	_add_tutorial_potion_instance()


func _reload_purification_potion() -> void:
	_add_tutorial_potion_instance()
	var slot := _equipped_slot
	if slot < 0 or slot >= _player_data.potion_slot_count:
		slot = clampi(_player_data.selected_potion_slot, 0, _player_data.potion_slot_count - 1)
	_player_data.move_equip_potion(slot, TARGET_POTION_ID)
	_player_data.select_potion_slot(slot)
	_equipped_slot = slot
	if _thrower.inventory_service != null:
		_thrower.inventory_service.setup(_player_data)
	_npc.report_purification_reloaded()
	purification_potion_reloaded.emit()
	if _top_hint != null:
		_top_hint.push_text("净化药水已耗尽，教程已自动补充并重新装填。", "sleeping_hound_reloaded", 4.0)


func _add_tutorial_potion_instance() -> void:
	var instance := PotionInstanceData.new()
	instance.potion_id = TARGET_POTION_ID
	instance.instance_uid = "tutorial-purification-%d" % Time.get_ticks_usec()
	instance.remaining_dose = 1.0
	instance.mixed_x = 0.72
	instance.quality = 1.0
	instance.potency = 1.0
	instance.duration = 1.0
	instance.price_multiplier = 1.0
	instance.created_day = 1
	var instances: Array = _player_data.potions.get(TARGET_POTION_ID, []).duplicate(true)
	instances.append(instance.to_dict())
	_player_data.potions[TARGET_POTION_ID] = instances
	if _thrower.inventory_service != null:
		_thrower.inventory_service.setup(_player_data)


func _find_player_data() -> PlayerData:
	var current: Node = get_parent()
	while current != null:
		if current.has_method("get_player_data"):
			return current.call("get_player_data") as PlayerData
		current = current.get_parent()
	return null


func _show_persistent_hint(hint_id: String, text: String) -> void:
	if _top_hint == null:
		return
	_top_hint.hide_interaction_hint(hint_id)
	_top_hint.show_interaction_hint(hint_id, text)


func _hide_hint(hint_id: String) -> void:
	if _top_hint != null:
		_top_hint.hide_interaction_hint(hint_id)
