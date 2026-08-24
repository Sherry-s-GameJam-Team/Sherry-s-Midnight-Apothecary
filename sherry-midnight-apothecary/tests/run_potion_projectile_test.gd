extends SceneTree

var failures := 0
var break_count := 0
var impact_point := Vector2.ZERO


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("POTION PROJECTILE TEST FAILED: %s" % message)


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var receiver := preload("res://tests/fixtures/potion_effect_receiver.gd").new()
	receiver.add_to_group("potion_friendly")
	var receiver_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(500, 30)
	receiver_shape.shape = rectangle
	receiver.add_child(receiver_shape)
	receiver.position = Vector2(0, 120)
	world.add_child(receiver)
	var preview := PotionTrajectoryPreview.new()
	world.add_child(preview)
	await physics_frame
	var throw_tuning: PotionThrowTuning = load("res://shared/potions/tuning/potion_throw_tuning.tres")
	var effect_tuning: PotionEffectTuning = load("res://shared/potions/tuning/potion_effect_tuning.tres")
	var launch_velocity := Vector2(180, -120)
	preview.update_preview(Vector2.ZERO, launch_velocity, throw_tuning, [])
	_expect(preview._line.points.size() > 2, "Trajectory preview produces bounded samples.")
	_expect(preview._impact.visible, "Trajectory preview stops on the first collider.")
	var predicted_impact := preview._impact.position
	var projectile: PotionProjectile = preload("res://shared/potions/runtime/potion_projectile.tscn").instantiate()
	world.add_child(projectile)
	projectile.global_position = Vector2.ZERO
	var potion: PotionData = load("res://shared/definitions/data/potions/red_potion.tres")
	var payload := {"potion_id": "red_potion", "quality": 1.0, "potency": 1.0, "duration": 1.0, "mixed_x": 0.05, "secondary_effect_id": "healing", "secondary_effect_multiplier": 0.5, "consumed_dose": 0.25, "effect_stack_multiplier": 4.0}
	projectile.configure(launch_velocity, payload, potion, throw_tuning, effect_tuning)
	projectile.broken.connect(_on_broken)
	for _frame in range(240):
		await physics_frame
		if break_count > 0:
			break
	_expect(break_count == 1, "Projectile breaks exactly once on first collision.")
	_expect(impact_point.distance_to(predicted_impact) < 20.0, "Real trajectory stays close to collision-aware preview.")
	_expect(receiver.received_effects.has(&"attack"), "Projectile delegates the red potion effect to the receiver.")
	_expect(receiver.received_effects.has(&"healing"), "A retained secondary effect executes at the same impact point.")
	_expect(float(receiver.last_context.get("amount", 0.0)) > 0.0, "Effect strength comes from tuning and potion attributes.")
	_expect(is_equal_approx(float(receiver.last_context.get("multiplier", 0.0)), 2.0), "Four-times charge also scales the half-strength secondary effect.")
	_expect(receiver.direct_hits.size() == 1, "A direct collision notifies the receiver exactly once.")
	if not receiver.direct_hits.is_empty():
		var direct_hit := receiver.direct_hits[0]
		_expect(direct_hit.get("potion_id") == &"red_potion", "Direct hit context identifies the thrown potion.")
		_expect(is_equal_approx(float(direct_hit.get("effect_multiplier", 0.0)), 4.0), "Direct hit context exposes the charged effect multiplier.")
		_expect(is_equal_approx(float(direct_hit.get("consumed_dose", 0.0)), 0.25), "Direct hit context exposes the committed dose.")
		_expect((direct_hit.get("impact_point", Vector2.ZERO) as Vector2).distance_to(impact_point) < 0.01, "Direct hit context uses the physical collision point.")
	var texture := PotionSvgRenderer.get_bottle_texture(Color(0.2, 0.8, 0.45), 64, 0.5, 1.0)
	_expect(texture != null and texture.get_width() > 0, "SVG bottle template renders to a reusable texture.")
	var base_color := PotionColorResolver.resolve(potion, {"mixed_x": 0.05, "quality": 1.0, "potency": 1.0})
	var varied_color := PotionColorResolver.resolve(potion, {"mixed_x": 0.15, "quality": 1.4, "potency": 1.2})
	_expect(base_color != varied_color, "Mix position, quality and potency produce a bounded per-dose color variation.")
	world.queue_free()
	await process_frame
	await process_frame
	PotionSvgRenderer.clear_cache()
	if failures == 0:
		print("Potion projectile, trajectory, SVG and effect tests passed.")
		quit(0)
	else:
		push_error("%d potion projectile assertion(s) failed." % failures)
		quit(1)


func _on_broken(point: Vector2, _normal: Vector2) -> void:
	break_count += 1
	impact_point = point
