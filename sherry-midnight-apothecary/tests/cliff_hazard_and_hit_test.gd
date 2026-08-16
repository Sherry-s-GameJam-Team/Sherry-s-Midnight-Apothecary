extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("CLIFF HAZARD HIT TEST FAILED: %s" % message)


func _run() -> void:
	var cliff_scene := load("res://day/levels/cliff/cliff.tscn") as PackedScene
	_expect(cliff_scene != null, "cliff.tscn loaded successfully")
	if cliff_scene == null:
		quit(1)
		return

	var level := cliff_scene.instantiate() as CliffResonanceLevel
	_expect(level != null, "cliff.tscn instantiated as CliffResonanceLevel")
	if level == null:
		quit(1)
		return

	root.add_child(level)

	# 1. Test DayLevelEnvironment / CliffResonanceLevel apply_player_damage
	_expect(level.has_method("apply_player_damage"), "CliffResonanceLevel implements apply_player_damage")
	var initial_health: int = level.get_player_data().health
	var damage_res: bool = level.apply_player_damage(15, &"resonance_wave")
	_expect(not damage_res, "Non-lethal damage returns false")
	_expect(level.get_player_data().health == initial_health - 15, "PlayerData health reduced by 15")

	# 2. Test Player hit animation setup
	var player := level.get_node("Player")
	_expect(player != null, "Player node found")
	var anim_player: AnimationPlayer = player.get_node_or_null("SherryPresentation/SherryAnimationPlayer")
	_expect(anim_player != null, "SherryAnimationPlayer exists")
	_expect(anim_player.has_animation("hit"), "hit animation exists in SherryAnimationPlayer")
	_expect(anim_player.has_animation("hit_right"), "hit_right animation exists in SherryAnimationPlayer")

	# 3. Test play_hazard_hit on Player
	player.call("play_hazard_hit", Vector2(-300.0, -150.0))
	_expect(player.get("_state") == "hit", "Player state is 'hit' after play_hazard_hit")
	_expect(anim_player.current_animation.begins_with("hit"), "SherryAnimationPlayer playing hit animation")
	_expect(player.get("_is_airborne") == true, "Player is airborne after upward knockback")

	# 4. Test CliffHazardController hit_player execution
	var hazard_controller := level.get_node_or_null("Hazards/CliffHazardController")
	_expect(hazard_controller != null, "CliffHazardController exists")
	var pre_hit_health: int = level.get_player_data().health
	hazard_controller.call("hit_player", player, &"avalanche", Vector2(1, 0), 400.0)
	_expect(level.get_player_data().health < pre_hit_health, "hit_player dealt damage via apply_player_damage")
	_expect(player.get("_state") == "hit", "Player state is 'hit' after hazard hit")

	level.queue_free()

	if failures == 0:
		print("Cliff hazard and player hit animation test PASSED.")
		quit(0)
	else:
		print("Cliff hazard and player hit animation test FAILED with %d errors." % failures)
		quit(1)
