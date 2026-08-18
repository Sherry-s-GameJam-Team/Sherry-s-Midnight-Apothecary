class_name AlkeonWeakpointIndicator
extends Node2D

## Animated visual targeting reticle and prompt indicator for Alkeon Boss weakpoint.

@onready var reticle_ring: Node2D = get_node_or_null("ReticleRing")
@onready var reticle_core: Node2D = get_node_or_null("ReticleCore")
@onready var pointer_arrow: Label = get_node_or_null("PointerArrow")
@onready var status_badge: Label = get_node_or_null("StatusBadge")
@onready var prompt_label: Label = get_node_or_null("PromptLabel")

var _is_active: bool = false
var _anim_time: float = 0.0
var _current_mode: String = "shield" # "shield", "core_exposed", "final_0", "final_1", "final_2"


func _ready() -> void:
	visible = false
	modulate.a = 0.0


func _process(delta: float) -> void:
	if not _is_active:
		return

	_anim_time += delta
	# Continuous rotation and pulsation of targeting reticle
	if reticle_ring != null:
		reticle_ring.rotation += delta * 1.8
		var pulse := 1.0 + sin(_anim_time * 6.0) * 0.08
		reticle_ring.scale = Vector2(pulse, pulse)

	if reticle_core != null:
		reticle_core.rotation -= delta * 2.5
		var core_pulse := 1.0 + cos(_anim_time * 8.0) * 0.12
		reticle_core.scale = Vector2(core_pulse, core_pulse)

	# Bouncing indicator arrow
	if pointer_arrow != null:
		pointer_arrow.position.y = -65.0 + sin(_anim_time * 5.0) * 6.0


func activate(mode: String = "shield") -> void:
	_is_active = true
	_current_mode = mode
	_update_labels()
	visible = true

	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	scale = Vector2(0.6, 0.6)
	tw.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func deactivate() -> void:
	_is_active = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "scale", Vector2(0.6, 0.6), 0.2)
	tw.tween_callback(func() -> void: visible = false)


func set_mode(mode: String) -> void:
	_current_mode = mode
	_is_active = true
	visible = true
	modulate.a = 1.0
	_update_labels()
	_play_mode_transition_flash()


func _update_labels() -> void:
	match _current_mode:
		"shield":
			if status_badge != null:
				status_badge.text = "【护盾保护中】"
				status_badge.modulate = Color(1.0, 0.8, 0.2, 1.0)
			if prompt_label != null:
				prompt_label.text = "⚡ 投掷 爆炸/净化 破盾"
				prompt_label.modulate = Color(1.0, 0.9, 0.3, 1.0)
			if reticle_ring != null:
				reticle_ring.modulate = Color(1.0, 0.6, 0.1, 0.9)
		"core_exposed":
			if status_badge != null:
				status_badge.text = "【核心暴露·弱点！】"
				status_badge.modulate = Color(0.3, 1.0, 0.8, 1.0)
			if prompt_label != null:
				prompt_label.text = "✨ 投掷 净化药水 造成重创！"
				prompt_label.modulate = Color(0.4, 1.0, 0.9, 1.0)
			if reticle_ring != null:
				reticle_ring.modulate = Color(0.2, 0.9, 1.0, 0.95)
		"final_execute", "final_0", "final_1", "final_2":
			if status_badge != null:
				status_badge.text = "【终极处决·核心外露】"
				status_badge.modulate = Color(1.0, 0.85, 0.2, 1.0)
			if prompt_label != null:
				prompt_label.text = "🌟 投掷【任意药水】执行最终处决！"
				prompt_label.modulate = Color(1.0, 0.95, 0.4, 1.0)
			if reticle_ring != null:
				reticle_ring.modulate = Color(1.0, 0.85, 0.2, 1.0)


func _play_mode_transition_flash() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.25, 1.25), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func play_hit_pulse() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.3, 1.3), 0.08)
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.12)
