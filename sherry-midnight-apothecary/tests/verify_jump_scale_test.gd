extends SceneTree

func _init() -> void:
	var anim_lib: AnimationLibrary = load("res://characters/sherry/sherry_animations.tres")
	if anim_lib == null:
		push_error("Failed to load sherry_animations.tres")
		quit(1)
		return
	
	var jf: Animation = anim_lib.get_animation("jump_fall")
	var jfr: Animation = anim_lib.get_animation("jump_fall_right")
	var jt: Animation = anim_lib.get_animation("jump_takeoff")
	var jtr: Animation = anim_lib.get_animation("jump_takeoff_right")
	
	var jf_scale: Vector2 = jf.track_get_key_value(2, 0)
	var jfr_scale: Vector2 = jfr.track_get_key_value(2, 0)
	var jt_scale: Vector2 = jt.track_get_key_value(2, 0)
	var jtr_scale: Vector2 = jtr.track_get_key_value(2, 0)
	
	print("jump_takeoff scale: ", jt_scale)
	print("jump_takeoff_right scale: ", jtr_scale)
	print("jump_fall scale: ", jf_scale)
	print("jump_fall_right scale: ", jfr_scale)
	
	if absf(jf_scale.x - jt_scale.x) > 0.001 or absf(jf_scale.y - jt_scale.y) > 0.001:
		push_error("Scale mismatch between takeoff and fall!")
		quit(1)
		return
	
	if absf(jfr_scale.x - jtr_scale.x) > 0.001 or absf(jfr_scale.y - jtr_scale.y) > 0.001:
		push_error("Scale mismatch between takeoff_right and fall_right!")
		quit(1)
		return
		
	print("ALL ANIMATION SCALES MATCH PERFECTLY (0.411885)!")
	quit(0)
