extends SceneTree


func _initialize() -> void:
	var tuning := load("res://shared/potions/tuning/potion_effect_tuning.tres") as PotionEffectTuning
	var executor := PotionEffectExecutor.new()
	executor.tuning = tuning
	var context := executor._make_context(
		&"lightning_meteor",
		1.0,
		{"quality": 1.0, "potency": 1.0},
		Vector2.ZERO,
		Vector2.UP,
		null
	)
	if float(context.get("amount", 0.0)) <= tuning.attack_damage or int(context.get("strike_count", 0)) != 3:
		push_error("Lightning and meteor effect context is invalid: %s" % context)
		executor.free()
		quit(1)
		return
	print("Lightning and meteor effect test passed.")
	executor.free()
	quit(0)
