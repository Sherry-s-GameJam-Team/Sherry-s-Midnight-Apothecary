class_name ForestCrownLevel
extends DayLevelEnvironment

const FOREST_COMPLETED_FLAG := "forest_completed"
const CROWN_COMPLETED_FLAG := "forest_crown_completed"
const BOSS_PURIFIED_FLAG := "forest_boss_purified"
const FOREST_LEVEL_ID := &"forest"
const FOREST_ENTRY_ID := &"from_crown"

@export var fall_damage := 10

@onready var player: CharacterBody2D = $Player
@onready var boss: SeraphBoss = $Boss
@onready var vfx: CrownVFXController = $CrownVFX
@onready var exit_portal: Area2D = $ExitPortal
@onready var exit_prompt: Label = $ExitPortal/Prompt
@onready var gauge_bar: ProgressBar = $UI/PurificationGauge/Margin/VBox/ProgressBar
@onready var gauge_label: Label = $UI/PurificationGauge/Margin/VBox/ValueLabel
@onready var boss_hint_label: Label = $UI/BossHint/Label
@onready var boss_hint_panel: PanelContainer = $UI/BossHint
@onready var fade_rect: ColorRect = $UI/FadeRect

var _respawning := false
var _player_in_portal := false


func _ready() -> void:
	super()
	fade_rect.modulate.a = 0.0
	if exit_portal != null:
		exit_portal.visible = false
		exit_portal.body_entered.connect(_on_portal_body_entered)
		exit_portal.body_exited.connect(_on_portal_body_exited)
	if exit_prompt != null:
		exit_prompt.visible = false

	if boss != null:
		boss.corruption_changed.connect(_on_boss_corruption_changed)
		boss.boss_state_changed.connect(_on_boss_state_changed)
		boss.boss_purified_completed.connect(_on_boss_purified_completed)

	_update_gauge(100.0, 100.0)

	# Check persistent completion state
	if _get_flag(FOREST_COMPLETED_FLAG) or _get_flag(BOSS_PURIFIED_FLAG):
		_apply_restored_state()
	else:
		_start_intro_sequence()


func _unhandled_input(event: InputEvent) -> void:
	if _player_in_portal and exit_portal != null and exit_portal.visible:
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
			var vp := get_viewport()
			if vp != null:
				vp.set_input_as_handled()
			_exit_to_forest()


func _start_intro_sequence() -> void:
	_show_hint("【暴雨与黑魔法笼罩了树冠……寻找净化窗口！】", 4.0)
	await get_tree().create_timer(1.2).timeout
	if boss != null:
		boss.start_encounter()


func _on_boss_corruption_changed(current: float, max_val: float) -> void:
	_update_gauge(current, max_val)


func _on_boss_state_changed(new_state: SeraphBoss.BossState) -> void:
	match new_state:
		SeraphBoss.BossState.BLOOD_RAIN:
			_show_hint("【黑魔法光环阻挡了净化……先击破光环！】", 3.5)
		SeraphBoss.BossState.PHASE1_EXPOSED:
			_show_hint("【光环已破裂！向炽天使投掷净化药水！】", 4.0)
		SeraphBoss.BossState.FEATHER_STORM:
			_show_hint("【利用抛物线与慢动作瞄准旋转的双重光环净化点！】", 4.0)
		SeraphBoss.BossState.PHASE2_EXPOSED:
			_show_hint("【防御崩溃！迅速进行两次净化！】", 4.5)
		SeraphBoss.BossState.CORRUPTION_CORE:
			_show_hint("【跳上高台躲避污染冲击波，投掷药水瓦解核心！】", 4.5)
		SeraphBoss.BossState.FINAL_PURIFICATION:
			_show_hint("【净化她。】", 6.0)
		SeraphBoss.BossState.RESTORED:
			_show_hint("【母树树冠已恢复生机。】", 4.0)


func _on_boss_purified_completed() -> void:
	_set_flag(FOREST_COMPLETED_FLAG, true)
	_set_flag(CROWN_COMPLETED_FLAG, true)
	_set_flag(BOSS_PURIFIED_FLAG, true)
	_apply_restored_state()


func _apply_restored_state() -> void:
	if exit_portal != null:
		exit_portal.visible = true
		exit_portal.monitoring = true
	var gauge: Control = $UI/PurificationGauge
	if gauge != null:
		var tween := create_tween()
		tween.tween_property(gauge, "modulate:a", 0.0, 1.5)


func _update_gauge(current: float, max_val: float) -> void:
	if gauge_bar != null:
		gauge_bar.max_value = max_val
		gauge_bar.value = current
	if gauge_label != null:
		gauge_label.text = "【 污染程度 】 %d%%" % roundi(current)


func _show_hint(text: String, duration: float) -> void:
	if boss_hint_panel == null or boss_hint_label == null:
		return
	boss_hint_label.text = text
	boss_hint_panel.visible = true
	boss_hint_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(boss_hint_panel, "modulate:a", 1.0, 0.3)
	tween.tween_interval(duration)
	tween.tween_property(boss_hint_panel, "modulate:a", 0.0, 0.5)
	await tween.finished
	if boss_hint_label.text == text:
		boss_hint_panel.visible = false


func request_respawn(body: Node2D, reason: String = "fall", damage: int = -1) -> void:
	if _respawning or not is_instance_valid(body):
		return
	var amount := fall_damage if damage < 0 else damage
	var runtime := _get_day_runtime()
	if runtime != null and amount > 0 and runtime.call("apply_player_damage", amount, StringName(reason)):
		return
	_respawning = true
	if body.has_method("set_control_enabled"):
		body.call("set_control_enabled", false)
	if body is CharacterBody2D:
		body.velocity = Vector2.ZERO

	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 0.2)
	await tween.finished

	body.global_position = $Arena/MainPlatform.global_position + Vector2(0, -60)
	if body is CharacterBody2D:
		body.velocity = Vector2.ZERO
	await get_tree().create_timer(0.08).timeout

	var tween_in := create_tween()
	tween_in.tween_property(fade_rect, "modulate:a", 0.0, 0.25)
	await tween_in.finished

	if body.has_method("set_control_enabled"):
		body.call("set_control_enabled", true)
	_respawning = false


func _on_portal_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_player_in_portal = true
		if exit_prompt != null:
			exit_prompt.visible = true


func _on_portal_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_player_in_portal = false
		if exit_prompt != null:
			exit_prompt.visible = false


func _exit_to_forest() -> void:
	var runtime := _get_day_runtime()
	if runtime != null and runtime.has_method("switch_to_level"):
		runtime.call("switch_to_level", FOREST_LEVEL_ID, FOREST_ENTRY_ID)
	elif runtime != null and runtime.has_method("transition_to_level_with_blackout"):
		runtime.call("transition_to_level_with_blackout", "forest", &"from_crown", true)
	else:
		push_warning("ForestCrown: switch_to_level not available; in F6 debug mode.")


func _set_flag(key: String, value: bool) -> void:
	var data := get_player_data()
	if data != null:
		data.tutorial_flags[key] = value


func _get_flag(key: String) -> bool:
	var data := get_player_data()
	return data != null and bool(data.tutorial_flags.get(key, false))


func _get_day_runtime() -> Node:
	var cursor: Node = get_parent()
	while cursor != null:
		if cursor.has_method("switch_to_level") or cursor.has_method("apply_player_damage"):
			return cursor
		cursor = cursor.get_parent()
	return null
