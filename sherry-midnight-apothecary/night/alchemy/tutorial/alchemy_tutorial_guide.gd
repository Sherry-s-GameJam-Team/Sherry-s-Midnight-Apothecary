class_name AlchemyTutorialGuide
extends Control

signal step_changed(step: Step)
signal tutorial_completed()

enum Step {
	NONE,
	OPEN_CODEX,
	VIEW_CODEX,
	GO_TO_PRODUCTION,
	DRAG_HERB_TO_BOARD,
	SEPARATE_HERB,
	DRAG_PIECE_TO_GRIND,
	GRIND_POWDER,
	DISCARD_LEAVES_TO_WASTE,
	PACK_POWDER,
	BACK_TO_BREWING,
	DRAG_POWDER_TO_CAULDRON,
	START_BREW,
	PUMP_BELLOWS,
	CONFIRM_BOTTLING,
	COMPLETED,
}

enum ArrowDir {
	UP,
	DOWN,
	LEFT,
	RIGHT,
}

const TUTORIAL_COMPLETED_FLAG := "day0_alchemy_tutorial_completed"

@export var enabled := true
@export var arrow_color := Color(1.0, 0.85, 0.25, 0.95)
@export var arrow_glow_color := Color(0.95, 0.55, 0.1, 0.45)
@export var bounce_distance := 14.0
@export var bounce_speed := 4.5

var current_step := Step.NONE
var is_active := false
var codex_viewed := false
var alchemy_runtime: AlchemyRuntime

var _bounce_time := 0.0
var _target_rect := Rect2()
var _source_point := Vector2.ZERO
var _target_point := Vector2.ZERO
var _has_trajectory := false
var _arrow_direction := ArrowDir.DOWN
var _banner_text := ""
var _step_title := ""
var _warning_cooldown := 0.0

@onready var banner_box: PanelContainer = $BannerBox
@onready var step_title_label: Label = $BannerBox/MarginContainer/VBoxContainer/StepTitleLabel
@onready var step_desc_label: RichTextLabel = $BannerBox/MarginContainer/VBoxContainer/StepDescLabel
@onready var arrow_indicator: Control = $ArrowIndicator


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if banner_box != null:
		banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if arrow_indicator != null:
		arrow_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func setup(runtime: AlchemyRuntime) -> void:
	alchemy_runtime = runtime
	if alchemy_runtime == null:
		return
	var player_data := alchemy_runtime.player_data
	var day := alchemy_runtime.day
	# Only active on Day 0 when not yet completed
	var completed := player_data != null and bool(player_data.tutorial_flags.get(TUTORIAL_COMPLETED_FLAG, false))
	if day == 0 and not completed and enabled:
		start_tutorial()
	else:
		stop_tutorial()


func start_tutorial() -> void:
	is_active = true
	visible = true
	codex_viewed = false
	current_step = Step.NONE
	_evaluate_step()


func stop_tutorial() -> void:
	is_active = false
	visible = false
	current_step = Step.COMPLETED


func complete_tutorial() -> void:
	if alchemy_runtime != null and alchemy_runtime.player_data != null:
		alchemy_runtime.player_data.tutorial_flags[TUTORIAL_COMPLETED_FLAG] = true
	stop_tutorial()
	tutorial_completed.emit()


func show_wrong_herb_warning() -> void:
	_step_title = "药材选择提示"
	_banner_text = "[color=#ff6b6b]当前需制作湛蓝净化药水，请选择【露水水囊草】进行加工。[/color]"
	if step_title_label != null:
		step_title_label.text = _step_title
	if step_desc_label != null:
		step_desc_label.text = _banner_text
	_warning_cooldown = 2.5


func _process(delta: float) -> void:
	if not is_active or alchemy_runtime == null:
		return
	_bounce_time += delta * bounce_speed
	if _warning_cooldown > 0.0:
		_warning_cooldown -= delta
	else:
		_evaluate_step()
	_update_visual_positions()
	queue_redraw()


func _evaluate_step() -> void:
	if not is_active or alchemy_runtime == null:
		return

	var next_step := Step.NONE
	var bottling := alchemy_runtime.bottling_panel
	var codex := alchemy_runtime.spectrum_codex_panel
	var prod := alchemy_runtime.production_panel
	var shelf := alchemy_runtime.unified_powder_shelf

	# Check bottling
	if bottling != null and bottling.visible:
		next_step = Step.CONFIRM_BOTTLING
	# Check brewing in progress
	elif alchemy_runtime.is_brewing():
		next_step = Step.PUMP_BELLOWS
	# Check codex opened
	elif codex != null and codex._is_open:
		codex_viewed = true
		next_step = Step.VIEW_CODEX
	# Initial prompt to open codex if not yet viewed
	elif not codex_viewed:
		next_step = Step.OPEN_CODEX
	# Panel is brewing
	elif alchemy_runtime.current_panel == AlchemyRuntime.PanelMode.BREWING:
		if not alchemy_runtime.cauldron_ingredients.is_empty():
			next_step = Step.START_BREW
		elif _has_blue_powder_on_shelf():
			next_step = Step.DRAG_POWDER_TO_CAULDRON
		else:
			next_step = Step.GO_TO_PRODUCTION
	# Panel is production
	elif alchemy_runtime.current_panel == AlchemyRuntime.PanelMode.PRODUCTION:
		if prod != null and prod.ground_powder != null:
			if _has_waste_pieces_on_board(prod):
				next_step = Step.DISCARD_LEAVES_TO_WASTE
			else:
				next_step = Step.PACK_POWDER
		elif prod != null and not prod.pieces.is_empty():
			var has_attached := false
			var has_grind := false
			var has_separated_grindable := false
			for piece in prod.pieces:
				if piece.state == ProductionRuntimeTypes.HerbPieceRuntime.State.ATTACHED:
					has_attached = true
				elif piece.state == ProductionRuntimeTypes.HerbPieceRuntime.State.GRIND:
					has_grind = true
				elif piece.state == ProductionRuntimeTypes.HerbPieceRuntime.State.SEPARATED and piece.data != null and piece.data.grindable:
					has_separated_grindable = true
			if has_attached:
				next_step = Step.SEPARATE_HERB
			elif has_grind:
				next_step = Step.GRIND_POWDER
			elif has_separated_grindable:
				next_step = Step.DRAG_PIECE_TO_GRIND
			elif _has_waste_pieces_on_board(prod):
				next_step = Step.DISCARD_LEAVES_TO_WASTE
			else:
				next_step = Step.PACK_POWDER
		elif _has_blue_powder_on_shelf():
			next_step = Step.BACK_TO_BREWING
		else:
			next_step = Step.DRAG_HERB_TO_BOARD

	if next_step != current_step:
		current_step = next_step
		step_changed.emit(current_step)
		_apply_step_content()


func _has_waste_pieces_on_board(prod: ProductionPanel) -> bool:
	if prod == null:
		return false
	for piece: ProductionRuntimeTypes.HerbPieceRuntime in prod.pieces:
		if piece != null and piece.state in [
			ProductionRuntimeTypes.HerbPieceRuntime.State.ATTACHED,
			ProductionRuntimeTypes.HerbPieceRuntime.State.SEPARATED,
		]:
			return true
	return false


func _has_blue_powder_on_shelf() -> bool:
	if alchemy_runtime == null or alchemy_runtime.powder_shelf_state == null:
		return false
	var powders: Array[PowderInstanceData] = alchemy_runtime.powder_shelf_state.list_powders()
	for powder: PowderInstanceData in powders:
		if powder != null and powder.source_ingredient_id == &"dew_flask_herb":
			return true
	# Also return true if any powder exists
	return not powders.is_empty()


func _apply_step_content() -> void:
	match current_step:
		Step.OPEN_CODEX:
			_step_title = "第一步：查阅光谱图鉴"
			_banner_text = "点击[color=#ffd700]上方光谱把手[/color]，查阅【湛蓝净化药水】配方与光谱波段特性。"
		Step.VIEW_CODEX:
			_step_title = "第一步：认知药性"
			_banner_text = "蓝光波段（0.71~0.86）主掌[color=#87cefa]净化与驱邪[/color]。查看后按 [color=#ffd700]ESC[/color] 或点击关闭收起图鉴。"
		Step.GO_TO_PRODUCTION:
			_step_title = "第二步：前往处理台"
			_banner_text = "点击右上角[color=#ffd700]黄色箭头[/color]，前往原料处理台加工草药。"
		Step.DRAG_HERB_TO_BOARD:
			_step_title = "第三步：取用药材"
			_banner_text = "将【露水水囊草】拖入中间砧板（[color=#87cefa]按住鼠标左键长按可多零件范围吸附[/color]）。"
		Step.SEPARATE_HERB:
			_step_title = "第四步：拆解部位"
			_banner_text = "点击「[color=#ffd700]分离[/color]」按钮，将草药拆解为绿叶与蓝色水珠部位。"
		Step.DRAG_PIECE_TO_GRIND:
			_step_title = "第五步：选取有效部位"
			_banner_text = "将蓝色的[color=#87cefa]水珠部位[/color]拖到右侧研磨区（[color=#87cefa]长按左键可范围内吸取零件[/color]）。"
		Step.GRIND_POWDER:
			_step_title = "第六步：研磨药粉"
			_banner_text = "点击「[color=#ffd700]研磨[/color]」按钮，生成纯净的蓝色药粉。"
		Step.DISCARD_LEAVES_TO_WASTE:
			_step_title = "装粉准备：清理废料"
			_banner_text = "装粉前需[color=#ffd700]保持案板整洁[/color]，请将除了水珠以外的多余[color=#87cefa]绿叶部位拖入左侧弃置箱[/color]。"
		Step.PACK_POWDER:
			_step_title = "第七步：装袋入架"
			_banner_text = "案板已清理整洁，点击「[color=#ffd700]打包[/color]」按钮将药粉装袋存入右侧药粉架。"
		Step.BACK_TO_BREWING:
			_step_title = "第八步：返回熬制台"
			_banner_text = "点击左侧[color=#ffd700]黄色箭头[/color]，返回熬制台准备炼制药水。"
		Step.DRAG_POWDER_TO_CAULDRON:
			_step_title = "第九步：投料入锅"
			_banner_text = "将药粉架上的[color=#87cefa]蓝色药粉[/color]拖入中间坩埚中。"
		Step.START_BREW:
			_step_title = "第十步：开始熬制"
			_banner_text = "点击「[color=#ffd700]熬制[/color]」按钮，开始加热萃取药液。"
		Step.PUMP_BELLOWS:
			_step_title = "第十一步：控温与蒸馏"
			_banner_text = "抽拉风箱提升温度并推进蒸馏（[color=#87cefa]鼠标左键点击 或 按【空格键】[/color]）。"
		Step.CONFIRM_BOTTLING:
			_step_title = "第十二步：装瓶入库"
			_banner_text = "选择心仪的药水瓶型并点击[color=#ffd700]确认[/color]，完成湛蓝净化药水制作！"
		_:
			_step_title = ""
			_banner_text = ""

	if step_title_label != null:
		step_title_label.text = _step_title
	if step_desc_label != null:
		step_desc_label.text = _banner_text


func _update_visual_positions() -> void:
	_has_trajectory = false
	var target_ctrl: Control = null
	var arrow_dir := ArrowDir.DOWN

	match current_step:
		Step.OPEN_CODEX:
			if alchemy_runtime.spectrum_codex_panel != null:
				target_ctrl = alchemy_runtime.spectrum_codex_panel.get_node_or_null("PullHandle") as Control
			arrow_dir = ArrowDir.UP
		Step.VIEW_CODEX:
			if alchemy_runtime.spectrum_codex_panel != null:
				target_ctrl = alchemy_runtime.spectrum_codex_panel.get_node_or_null("%CloseButton") as Control
			arrow_dir = ArrowDir.UP
		Step.GO_TO_PRODUCTION:
			target_ctrl = alchemy_runtime.to_production_arrow
			arrow_dir = ArrowDir.RIGHT
		Step.DRAG_HERB_TO_BOARD:
			var herb_grid := alchemy_runtime.get_node_or_null("StageRoot/HorizontalStage/ProductionPanel/%HerbGrid") as Control
			var board := alchemy_runtime.get_node_or_null("StageRoot/HorizontalStage/ProductionPanel/%ProcessBoard") as Control
			if herb_grid != null and herb_grid.get_child_count() > 0:
				target_ctrl = herb_grid.get_child(0) as Control
				if board != null:
					_has_trajectory = true
					_source_point = target_ctrl.get_global_rect().get_center()
					_target_point = board.get_global_rect().get_center()
			arrow_dir = ArrowDir.RIGHT
		Step.SEPARATE_HERB:
			target_ctrl = alchemy_runtime.get_node_or_null("StageRoot/HorizontalStage/ProductionPanel/%SeparateButton") as Control
			arrow_dir = ArrowDir.DOWN
		Step.DRAG_PIECE_TO_GRIND:
			var board := alchemy_runtime.get_node_or_null("StageRoot/HorizontalStage/ProductionPanel/%ProcessBoard") as ProcessBoard
			if board != null:
				var piece_views := board.get_piece_views()
				for view in piece_views:
					if view.is_movable() and view.piece != null and view.piece.state == ProductionRuntimeTypes.HerbPieceRuntime.State.SEPARATED and view.piece.data != null and view.piece.data.grindable:
						target_ctrl = view
						break
				var grind_rect: Rect2 = board.get_grind_detection_rect()
				_has_trajectory = true
				_source_point = target_ctrl.global_position if target_ctrl != null else board.get_global_rect().get_center()
				_target_point = grind_rect.get_center()
			arrow_dir = ArrowDir.RIGHT
		Step.GRIND_POWDER:
			target_ctrl = alchemy_runtime.get_node_or_null("StageRoot/HorizontalStage/ProductionPanel/%GrindButton") as Control
			arrow_dir = ArrowDir.DOWN
		Step.DISCARD_LEAVES_TO_WASTE:
			var board := alchemy_runtime.get_node_or_null("StageRoot/HorizontalStage/ProductionPanel/%ProcessBoard") as ProcessBoard
			if board != null:
				var piece_views := board.get_piece_views()
				for view in piece_views:
					if view.is_movable() and view.piece != null and view.piece.state in [
						ProductionRuntimeTypes.HerbPieceRuntime.State.ATTACHED,
						ProductionRuntimeTypes.HerbPieceRuntime.State.SEPARATED,
					]:
						target_ctrl = view
						break
				var waste_rect: Rect2 = board.get_waste_detection_rect()
				_has_trajectory = true
				_source_point = target_ctrl.global_position if target_ctrl != null else board.get_global_rect().get_center()
				_target_point = waste_rect.get_center()
			arrow_dir = ArrowDir.LEFT
		Step.PACK_POWDER:
			target_ctrl = alchemy_runtime.get_node_or_null("StageRoot/HorizontalStage/ProductionPanel/%PackPowderButton") as Control
			arrow_dir = ArrowDir.DOWN
		Step.BACK_TO_BREWING:
			target_ctrl = alchemy_runtime.back_to_brewing_arrow
			arrow_dir = ArrowDir.LEFT
		Step.DRAG_POWDER_TO_CAULDRON:
			var shelf := alchemy_runtime.unified_powder_shelf
			var cauldron := alchemy_runtime.cauldron
			if shelf != null:
				var slots := shelf.get_node_or_null("%SlotGrid") as Control
				if slots != null and slots.get_child_count() > 0:
					target_ctrl = slots.get_child(0) as Control
				else:
					target_ctrl = shelf
			if target_ctrl != null and cauldron != null:
				_has_trajectory = true
				_source_point = target_ctrl.get_global_rect().get_center()
				_target_point = cauldron.get_global_rect().get_center()
			arrow_dir = ArrowDir.LEFT
		Step.START_BREW:
			target_ctrl = alchemy_runtime.brew_button
			arrow_dir = ArrowDir.DOWN
		Step.PUMP_BELLOWS:
			target_ctrl = alchemy_runtime.bellows_control
			arrow_dir = ArrowDir.UP
		Step.CONFIRM_BOTTLING:
			if alchemy_runtime.bottling_panel != null:
				target_ctrl = alchemy_runtime.bottling_panel.get_node_or_null("%ConfirmButton") as Control
			arrow_dir = ArrowDir.UP

	_arrow_direction = arrow_dir

	if target_ctrl != null and target_ctrl.is_inside_tree() and target_ctrl.is_visible_in_tree():
		_target_rect = target_ctrl.get_global_rect()
		arrow_indicator.visible = true
		_position_arrow(_target_rect, arrow_dir)
	else:
		arrow_indicator.visible = false


func _position_arrow(rect: Rect2, dir: ArrowDir) -> void:
	if arrow_indicator == null:
		return
	var offset := sin(_bounce_time) * bounce_distance
	var center := rect.get_center()

	match dir:
		ArrowDir.DOWN:
			arrow_indicator.global_position = Vector2(center.x, rect.position.y - 48.0 - offset)
			arrow_indicator.rotation = 0.0
		ArrowDir.UP:
			arrow_indicator.global_position = Vector2(center.x, rect.end.y + 48.0 + offset)
			arrow_indicator.rotation = PI
		ArrowDir.RIGHT:
			arrow_indicator.global_position = Vector2(rect.position.x - 48.0 - offset, center.y)
			arrow_indicator.rotation = -PI * 0.5
		ArrowDir.LEFT:
			arrow_indicator.global_position = Vector2(rect.end.x + 48.0 + offset, center.y)
			arrow_indicator.rotation = PI * 0.5


func _draw() -> void:
	if not is_active or not _has_trajectory:
		return

	# Draw animated dashed trajectory curve from source to target
	var start := _source_point
	var end := _target_point
	var control_pt := Vector2((start.x + end.x) * 0.5, minf(start.y, end.y) - 60.0)

	var points: Array[Vector2] = []
	var segments := 24
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var p := (1.0 - t) * (1.0 - t) * start + 2.0 * (1.0 - t) * t * control_pt + t * t * end
		points.append(p)

	var anim_offset := fmod(_bounce_time * 20.0, 20.0)
	for i in range(points.size() - 1):
		if fmod(float(i * 12) + anim_offset, 24.0) < 12.0:
			draw_line(points[i], points[i + 1], Color(1.0, 0.85, 0.25, 0.55), 3.5, true)
			draw_line(points[i], points[i + 1], Color(1.0, 1.0, 1.0, 0.85), 1.5, true)

	# Draw moving chevron bead along path
	var bead_t := fmod(_bounce_time * 0.35, 1.0)
	var bead_pos := (1.0 - bead_t) * (1.0 - bead_t) * start + 2.0 * (1.0 - bead_t) * bead_t * control_pt + bead_t * bead_t * end
	draw_circle(bead_pos, 6.0, Color(1.0, 0.9, 0.3, 0.9))
	draw_circle(bead_pos, 10.0, Color(1.0, 0.7, 0.1, 0.4))
