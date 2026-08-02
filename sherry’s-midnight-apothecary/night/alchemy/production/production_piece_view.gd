class_name ProductionPieceView
extends Control

signal drag_started(view: ProductionPieceView)
signal drag_position_requested(view: ProductionPieceView, desired_global_position: Vector2)
signal drag_finished(view: ProductionPieceView)

const OUTLINE_SHADER := preload("res://night/alchemy/production/shaders/herb_piece_outline.gdshader")
const VISUAL_PADDING := 5.0

enum OutlineState { NONE, HOVER, MULTI_CANDIDATE, GRABBED }

@export var hover_outline_color := Color(1.0, 0.86, 0.45, 0.95)
@export_range(1.0, 8.0) var hover_outline_width := 2.0
@export_range(0.0, 1.0, 0.01) var interaction_alpha_threshold := 0.03
@export_range(0, 16, 1) var interaction_dilation_pixels := 5
@export_range(0, 16, 1) var small_piece_extra_dilation := 3
@export_range(0, 32, 1) var interaction_hole_fill_radius := 2

var piece: ProductionRuntimeTypes.HerbPieceRuntime
var is_dragging := false
var drag_grab_offset := Vector2.ZERO
var drag_original_parent: Control
var drag_start_position := Vector2.ZERO
var magnet_pickup_blocked := false

var artwork: TextureRect
var hover_outline: TextureRect
var _alpha_bitmap: BitMap
var _interaction_bitmap: BitMap
var _texture_size := Vector2i.ZERO
var _interaction_edge_pixels: Array[Vector2i] = []
var _visual_alpha_pixels := 0
var _interaction_area_pixels := 0
var _outline_state := OutlineState.NONE
var _outline_material: ShaderMaterial
var _pickup_anchor_normalized := Vector2(0.5, 0.5)
var _base_scale := Vector2.ONE


func setup(value: ProductionRuntimeTypes.HerbPieceRuntime, display_size := Vector2(48.0, 48.0)) -> void:
	piece = value
	name = str(piece.data.id) if piece != null and piece.data != null else "HerbPieceView"
	# The board owns pointer input so empty-space searching and overlapping
	# transparent sprites never compete for GUI events.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = display_size
	size = display_size
	_base_scale = scale
	_build_visual()
	build_interaction_mask()
	_update_state_visual()
	rotation_degrees = piece.scatter_rotation if piece != null else 0.0
	tooltip_text = _piece_tooltip()


func _build_visual() -> void:
	artwork = TextureRect.new()
	artwork.name = "Artwork"
	artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	artwork.offset_left = VISUAL_PADDING
	artwork.offset_top = VISUAL_PADDING
	artwork.offset_right = -VISUAL_PADDING
	artwork.offset_bottom = -VISUAL_PADDING
	artwork.texture = piece.data.texture if piece != null and piece.data != null else null
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(artwork)

	hover_outline = TextureRect.new()
	hover_outline.name = "HoverOutline"
	hover_outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hover_outline.offset_left = VISUAL_PADDING
	hover_outline.offset_top = VISUAL_PADDING
	hover_outline.offset_right = -VISUAL_PADDING
	hover_outline.offset_bottom = -VISUAL_PADDING
	hover_outline.texture = artwork.texture
	hover_outline.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hover_outline.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hover_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outline_material = ShaderMaterial.new()
	_outline_material.shader = OUTLINE_SHADER
	_outline_material.set_shader_parameter("outline_enabled", false)
	_outline_material.set_shader_parameter("outline_color", hover_outline_color)
	_outline_material.set_shader_parameter("outline_width", hover_outline_width)
	hover_outline.material = _outline_material
	add_child(hover_outline)


func _build_alpha_bitmap() -> void:
	_alpha_bitmap = null
	_texture_size = Vector2i.ZERO
	if artwork == null or artwork.texture == null:
		return
	var image := artwork.texture.get_image()
	if image == null or image.is_empty():
		return
	_texture_size = image.get_size()
	_alpha_bitmap = BitMap.new()
	_alpha_bitmap.create_from_image_alpha(image, interaction_alpha_threshold)
	_cache_pickup_anchor(image)


func rebuild_interaction_mask() -> void:
	_build_alpha_bitmap()
	_interaction_bitmap = null
	_interaction_edge_pixels.clear()
	_visual_alpha_pixels = 0
	_interaction_area_pixels = 0
	if _alpha_bitmap == null or _texture_size.x <= 0 or _texture_size.y <= 0:
		return
	_interaction_bitmap = BitMap.new()
	_interaction_bitmap.create(_texture_size)
	for y in _texture_size.y:
		for x in _texture_size.x:
			if _alpha_bitmap.get_bit(x, y):
				_visual_alpha_pixels += 1
	var image_area := _texture_size.x * _texture_size.y
	var small_piece := _visual_alpha_pixels <= maxi(256, floori(float(image_area) * 0.12))
	var extra := small_piece_extra_dilation if small_piece else 0
	var radius := interaction_dilation_pixels + extra
	_build_dilated_interaction_mask(radius)
	# Keep an explicit edge cache. Runtime hover/magnet checks never read Image data.
	for y in _texture_size.y:
		for x in _texture_size.x:
			if not _interaction_bitmap.get_bit(x, y):
				continue
			_interaction_area_pixels += 1
			if _is_interaction_edge(x, y):
				_interaction_edge_pixels.append(Vector2i(x, y))


func build_interaction_mask() -> void:
	rebuild_interaction_mask()


func _build_dilated_interaction_mask(radius: int) -> void:
	# A two-pass Manhattan distance field is linear in the image size. The old
	# "paint a disc for every opaque pixel" approach became prohibitively slow
	# when a dense herb was separated into many high-resolution pieces.
	var width := _texture_size.x
	var height := _texture_size.y
	var distances := PackedInt32Array()
	distances.resize(width * height)
	distances.fill(radius + 1)
	for y in height:
		for x in width:
			var index := y * width + x
			if _alpha_bitmap.get_bit(x, y) or _is_small_hole_pixel(x, y):
				distances[index] = 0
				continue
			if x > 0:
				distances[index] = mini(distances[index], distances[index - 1] + 1)
			if y > 0:
				distances[index] = mini(distances[index], distances[index - width] + 1)
	for y in range(height - 1, -1, -1):
		for x in range(width - 1, -1, -1):
			var index := y * width + x
			if x + 1 < width:
				distances[index] = mini(distances[index], distances[index + 1] + 1)
			if y + 1 < height:
				distances[index] = mini(distances[index], distances[index + width] + 1)
			if distances[index] <= radius:
				_interaction_bitmap.set_bit(x, y, true)


func _is_small_hole_pixel(x: int, y: int) -> bool:
	if interaction_hole_fill_radius <= 0 or _alpha_bitmap == null or _alpha_bitmap.get_bit(x, y):
		return false
	var left := false
	var right := false
	var up := false
	var down := false
	for offset in range(1, interaction_hole_fill_radius + 1):
		left = left or (x - offset >= 0 and _alpha_bitmap.get_bit(x - offset, y))
		right = right or (x + offset < _texture_size.x and _alpha_bitmap.get_bit(x + offset, y))
		up = up or (y - offset >= 0 and _alpha_bitmap.get_bit(x, y - offset))
		down = down or (y + offset < _texture_size.y and _alpha_bitmap.get_bit(x, y + offset))
	return left and right and up and down


func _is_interaction_edge(x: int, y: int) -> bool:
	for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var point: Vector2i = Vector2i(x, y) + offset
		if point.x < 0 or point.y < 0 or point.x >= _texture_size.x or point.y >= _texture_size.y or not _interaction_bitmap.get_bit(point.x, point.y):
			return true
	return false


func _cache_pickup_anchor(image: Image) -> void:
	_pickup_anchor_normalized = Vector2(0.5, 0.5)
	if image == null or image.is_empty():
		return
	if piece != null and piece.data != null and not piece.data.pickup_anchor_normalized.is_equal_approx(Vector2(0.5, 0.5)):
		_pickup_anchor_normalized = Vector2(
			clampf(piece.data.pickup_anchor_normalized.x, 0.0, 1.0),
			clampf(piece.data.pickup_anchor_normalized.y, 0.0, 1.0)
		)
		return
	# A bounded sample keeps setup cheap even for unusually large source PNGs.
	var sample_step := maxi(1, ceili(float(maxi(image.get_width(), image.get_height())) / 256.0))
	var weighted_sum := Vector2.ZERO
	var alpha_sum := 0.0
	for y in range(0, image.get_height(), sample_step):
		for x in range(0, image.get_width(), sample_step):
			var alpha := image.get_pixel(x, y).a
			if alpha < 0.1:
				continue
			weighted_sum += (Vector2(x, y) + Vector2(0.5, 0.5)) * alpha
			alpha_sum += alpha
	if alpha_sum > 0.0:
		_pickup_anchor_normalized = weighted_sum / alpha_sum / Vector2(image.get_size())


func _has_point(point: Vector2) -> bool:
	if _alpha_bitmap == null or _texture_size.x <= 0 or _texture_size.y <= 0:
		return Rect2(Vector2.ZERO, size).has_point(point)
	var draw_rect := _texture_draw_rect()
	if not draw_rect.has_point(point) or draw_rect.size.x <= 0.0 or draw_rect.size.y <= 0.0:
		return false
	var uv := (point - draw_rect.position) / draw_rect.size
	var pixel := Vector2i(
		clampi(floori(uv.x * _texture_size.x), 0, _texture_size.x - 1),
		clampi(floori(uv.y * _texture_size.y), 0, _texture_size.y - 1)
	)
	return _alpha_bitmap.get_bit(pixel.x, pixel.y)


func global_point_to_mask_pixel(global_point: Vector2) -> Vector2i:
	if _texture_size.x <= 0 or _texture_size.y <= 0:
		return Vector2i(-1, -1)
	var local_point: Vector2 = get_global_transform().affine_inverse() * global_point
	var draw_rect := _texture_draw_rect()
	if not draw_rect.has_point(local_point):
		return Vector2i(-1, -1)
	var uv: Vector2 = (local_point - draw_rect.position) / draw_rect.size
	return Vector2i(clampi(floori(uv.x * _texture_size.x), 0, _texture_size.x - 1), clampi(floori(uv.y * _texture_size.y), 0, _texture_size.y - 1))


func _texture_draw_rect() -> Rect2:
	var available := Rect2(
		Vector2(VISUAL_PADDING, VISUAL_PADDING),
		Vector2(maxf(size.x - VISUAL_PADDING * 2.0, 0.0), maxf(size.y - VISUAL_PADDING * 2.0, 0.0))
	)
	if _texture_size.x <= 0 or _texture_size.y <= 0 or available.size.x <= 0.0 or available.size.y <= 0.0:
		return available
	var scale_factor := minf(available.size.x / _texture_size.x, available.size.y / _texture_size.y)
	var draw_size := Vector2(_texture_size) * scale_factor
	return Rect2(available.position + (available.size - draw_size) * 0.5, draw_size)


func get_local_content_rect() -> Rect2:
	return _texture_draw_rect()


func contains_global_point(global_point: Vector2) -> bool:
	var pixel := global_point_to_mask_pixel(global_point)
	return pixel.x >= 0 and _interaction_bitmap != null and _interaction_bitmap.get_bit(pixel.x, pixel.y)


func distance_to_interaction_area(global_point: Vector2) -> float:
	if contains_global_point(global_point):
		return 0.0
	if _interaction_edge_pixels.is_empty() or _texture_size.x <= 0 or _texture_size.y <= 0:
		return INF
	var local_point: Vector2 = get_global_transform().affine_inverse() * global_point
	var draw_rect := _texture_draw_rect()
	if draw_rect.size.x <= 0.0 or draw_rect.size.y <= 0.0:
		return INF
	var pixel_point := (local_point - draw_rect.position) / draw_rect.size * Vector2(_texture_size)
	var nearest := INF
	for edge: Vector2i in _interaction_edge_pixels:
		nearest = minf(nearest, pixel_point.distance_to(Vector2(edge)))
	var scale := get_global_transform().get_scale().abs()
	var pixels_to_global := minf(draw_rect.size.x / _texture_size.x * scale.x, draw_rect.size.y / _texture_size.y * scale.y)
	return nearest * pixels_to_global


func get_global_content_rect() -> Rect2:
	var local_rect := get_local_content_rect()
	var transform := get_global_transform()
	var points: Array[Vector2] = [
		transform * local_rect.position,
		transform * Vector2(local_rect.end.x, local_rect.position.y),
		transform * local_rect.end,
		transform * Vector2(local_rect.position.x, local_rect.end.y),
	]
	var result := Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		result = result.expand(point)
	return result


func get_scaled_pickup_anchor() -> Vector2:
	var draw_rect := _texture_draw_rect()
	var local_anchor := draw_rect.position + draw_rect.size * _pickup_anchor_normalized
	return get_global_transform() * local_anchor - global_position


func set_magnet_emphasis(enabled: bool, enlarge := false) -> void:
	var preserved_global_position := global_position
	pivot_offset = size * 0.5
	scale = _base_scale * (1.025 if enabled and enlarge else 1.0)
	global_position = preserved_global_position
	set_outline_state(OutlineState.GRABBED if enabled else OutlineState.NONE)


func set_outline_enabled(enabled: bool) -> void:
	set_outline_state(OutlineState.HOVER if enabled else OutlineState.NONE)


func set_outline_state(value: OutlineState) -> void:
	_outline_state = value
	if _outline_material == null:
		return
	_outline_material.set_shader_parameter("outline_enabled", value != OutlineState.NONE)
	if value == OutlineState.MULTI_CANDIDATE:
		_outline_material.set_shader_parameter("outline_color", Color(0.75, 0.86, 1.0, 0.62))
	elif value == OutlineState.GRABBED:
		_outline_material.set_shader_parameter("outline_color", Color(1.0, 0.9, 0.42, 1.0))
	else:
		_outline_material.set_shader_parameter("outline_color", hover_outline_color)


func refresh_state_visual() -> void:
	_update_state_visual()


func _update_state_visual() -> void:
	if artwork == null or piece == null:
		return
	match piece.state:
		ProductionRuntimeTypes.HerbPieceRuntime.State.WASTE:
			artwork.modulate = Color(1.0, 1.0, 1.0, 0.58)
		ProductionRuntimeTypes.HerbPieceRuntime.State.GRIND:
			artwork.modulate = Color(1.15, 1.04, 0.72, 1.0)
		_:
			artwork.modulate = Color.WHITE
	if is_dragging:
		artwork.modulate = artwork.modulate.lightened(0.08)


func _gui_input(event: InputEvent) -> void:
	if not _is_piece_movable():
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		if button.pressed:
			_begin_drag_at(get_global_mouse_position())
		else:
			_end_drag()
		accept_event()
	elif event is InputEventMouseMotion and is_dragging:
		_update_drag_to(get_global_mouse_position())
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_EXIT_TREE:
		force_cancel_drag()


func _begin_drag_at(mouse_global_position: Vector2) -> void:
	if is_dragging or not _is_piece_movable():
		return
	is_dragging = true
	drag_grab_offset = mouse_global_position - global_position
	drag_original_parent = get_parent() as Control
	drag_start_position = global_position
	set_outline_enabled(true)
	_update_state_visual()
	drag_started.emit(self)


func _update_drag_to(mouse_global_position: Vector2) -> void:
	if not is_dragging:
		return
	drag_position_requested.emit(self, mouse_global_position - drag_grab_offset)


func _end_drag() -> void:
	if not is_dragging:
		return
	is_dragging = false
	_update_state_visual()
	drag_finished.emit(self)
	set_outline_enabled(_has_point(get_local_mouse_position()))


func force_cancel_drag() -> void:
	if not is_dragging:
		return
	is_dragging = false
	set_outline_enabled(false)
	_update_state_visual()


func restore_after_magnet_cancel() -> void:
	is_dragging = false
	set_magnet_emphasis(false)
	_update_state_visual()


func _is_piece_movable() -> bool:
	return not magnet_pickup_blocked and piece != null and piece.state in [
		ProductionRuntimeTypes.HerbPieceRuntime.State.SEPARATED,
		ProductionRuntimeTypes.HerbPieceRuntime.State.WASTE,
		ProductionRuntimeTypes.HerbPieceRuntime.State.GRIND,
	]


func is_movable() -> bool:
	return _is_piece_movable()


func _piece_tooltip() -> String:
	if piece == null or piece.data == null:
		return ""
	return "%s\n色值 %.3f · 产出 %.1f%%\n品质 %.2f · 浓度 %.2f" % [
		piece.data.display_name,
		piece.data.spectrum_x,
		piece.effective_yield() * 100.0,
		piece.quality,
		piece.concentration,
	]
