class_name LetterViewerDialog
extends CanvasLayer

## Letter Viewer Dialog with stack shuffle/flip animation.
## Displays the 3 letters from res://day/levels/Vespervale/letter/
## Supports slide-away and place-to-bottom card flip effect.

signal viewer_closed

const LETTER_TEXTURES: Array[Texture2D] = [
	preload("res://day/levels/Vespervale/letter/letter1.png"),
	preload("res://day/levels/Vespervale/letter/letter2.png"),
	preload("res://day/levels/Vespervale/letter/letter3.png")
]

const STACK_CONFIGS: Array[Dictionary] = [
	{ "pos": Vector2(0, 0), "scale": Vector2(1.0, 1.0), "z": 3, "alpha": 1.0 },   # Top card
	{ "pos": Vector2(0, 16), "scale": Vector2(0.93, 0.93), "z": 2, "alpha": 0.85 }, # Middle card
	{ "pos": Vector2(0, 30), "scale": Vector2(0.86, 0.86), "z": 1, "alpha": 0.65 }  # Bottom card
]

var _top_order: Array[int] = [0, 1, 2] # Tracks which card index is in which stack position [top, mid, bottom]
var _is_animating: bool = false

@onready var backdrop: ColorRect = get_node_or_null("Backdrop")
@onready var center_anchor: Control = get_node_or_null("CenterContainer/CardAnchor")
@onready var card_nodes: Array[TextureRect] = [
	get_node_or_null("CenterContainer/CardAnchor/Card0") as TextureRect,
	get_node_or_null("CenterContainer/CardAnchor/Card1") as TextureRect,
	get_node_or_null("CenterContainer/CardAnchor/Card2") as TextureRect
]
@onready var prev_button: Button = get_node_or_null("Navigation/PrevButton")
@onready var next_button: Button = get_node_or_null("Navigation/NextButton")
@onready var close_button: Button = get_node_or_null("CloseButton")
@onready var page_indicator: Label = get_node_or_null("PageIndicator")


func _ready() -> void:
	visible = false
	if close_button != null:
		close_button.pressed.connect(close_viewer)
	if prev_button != null:
		prev_button.pressed.connect(prev_card)
	if next_button != null:
		next_button.pressed.connect(next_card)

	for i in range(card_nodes.size()):
		if card_nodes[i] != null and i < LETTER_TEXTURES.size():
			card_nodes[i].texture = LETTER_TEXTURES[i]


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close_viewer()
		elif event.keycode == KEY_A or event.keycode == KEY_LEFT:
			get_viewport().set_input_as_handled()
			prev_card()
		elif event.keycode == KEY_D or event.keycode == KEY_RIGHT or event.keycode == KEY_SPACE or event.keycode == KEY_E:
			get_viewport().set_input_as_handled()
			next_card()


func open_viewer() -> void:
	_top_order = [0, 1, 2]
	_is_animating = false
	visible = true
	_apply_stack_positions_instant()
	_update_page_indicator()

	# Fade in backdrop
	if backdrop != null:
		backdrop.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(backdrop, "modulate:a", 0.78, 0.25)


func close_viewer() -> void:
	if backdrop != null:
		var tw := create_tween()
		tw.tween_property(backdrop, "modulate:a", 0.0, 0.2)
		tw.tween_callback(func() -> void:
			visible = false
			viewer_closed.emit()
		)
	else:
		visible = false
		viewer_closed.emit()


func next_card() -> void:
	if _is_animating or not visible:
		return
	_is_animating = true

	# Old top card slides out to the right, moves to bottom z-index, and returns underneath
	var top_card_idx := _top_order[0]
	var mid_card_idx := _top_order[1]
	var bot_card_idx := _top_order[2]

	var top_card := card_nodes[top_card_idx]
	var mid_card := card_nodes[mid_card_idx]
	var bot_card := card_nodes[bot_card_idx]

	var tw := create_tween()
	tw.set_parallel(true)

	# 1. Slide top card outward
	tw.tween_property(top_card, "position:x", 360.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(top_card, "rotation", 0.12, 0.22)
	tw.tween_property(top_card, "modulate:a", 0.65, 0.22)

	# 2. Promote middle card to top
	tw.tween_property(mid_card, "position", STACK_CONFIGS[0]["pos"], 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(mid_card, "scale", STACK_CONFIGS[0]["scale"], 0.35)
	tw.tween_property(mid_card, "modulate:a", STACK_CONFIGS[0]["alpha"], 0.35)

	# 3. Promote bottom card to middle
	tw.tween_property(bot_card, "position", STACK_CONFIGS[1]["pos"], 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(bot_card, "scale", STACK_CONFIGS[1]["scale"], 0.35)
	tw.tween_property(bot_card, "modulate:a", STACK_CONFIGS[1]["alpha"], 0.35)

	# Mid-point callback: change top card Z-index to behind and slide into bottom slot
	tw.chain().tween_callback(func() -> void:
		top_card.z_index = STACK_CONFIGS[2]["z"]
		mid_card.z_index = STACK_CONFIGS[0]["z"]
		bot_card.z_index = STACK_CONFIGS[1]["z"]
	)

	var tw2 := create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(top_card, "position", STACK_CONFIGS[2]["pos"], 0.25).set_delay(0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw2.tween_property(top_card, "rotation", 0.0, 0.25).set_delay(0.22)
	tw2.tween_property(top_card, "scale", STACK_CONFIGS[2]["scale"], 0.25).set_delay(0.22)
	tw2.tween_property(top_card, "modulate:a", STACK_CONFIGS[2]["alpha"], 0.25).set_delay(0.22)

	tw2.chain().tween_callback(func() -> void:
		# Shift order: [1, 2, 0]
		_top_order = [mid_card_idx, bot_card_idx, top_card_idx]
		_is_animating = false
		_update_page_indicator()
	)


func prev_card() -> void:
	if _is_animating or not visible:
		return
	_is_animating = true

	# Bottom card slides out from behind to the left, elevates to top, and slides over front
	var top_card_idx := _top_order[0]
	var mid_card_idx := _top_order[1]
	var bot_card_idx := _top_order[2]

	var top_card := card_nodes[top_card_idx]
	var mid_card := card_nodes[mid_card_idx]
	var bot_card := card_nodes[bot_card_idx]

	var tw := create_tween()
	tw.set_parallel(true)

	# 1. Slide bottom card outward to left
	tw.tween_property(bot_card, "position:x", -360.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(bot_card, "rotation", -0.12, 0.22)
	tw.tween_property(bot_card, "modulate:a", 0.85, 0.22)

	# 2. Push top card to middle
	tw.tween_property(top_card, "position", STACK_CONFIGS[1]["pos"], 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(top_card, "scale", STACK_CONFIGS[1]["scale"], 0.35)
	tw.tween_property(top_card, "modulate:a", STACK_CONFIGS[1]["alpha"], 0.35)

	# 3. Push middle card to bottom
	tw.tween_property(mid_card, "position", STACK_CONFIGS[2]["pos"], 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mid_card, "scale", STACK_CONFIGS[2]["scale"], 0.35)
	tw.tween_property(mid_card, "modulate:a", STACK_CONFIGS[2]["alpha"], 0.35)

	# Mid-point callback: elevate bottom card to front
	tw.chain().tween_callback(func() -> void:
		bot_card.z_index = STACK_CONFIGS[0]["z"]
		top_card.z_index = STACK_CONFIGS[1]["z"]
		mid_card.z_index = STACK_CONFIGS[2]["z"]
	)

	var tw2 := create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(bot_card, "position", STACK_CONFIGS[0]["pos"], 0.25).set_delay(0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw2.tween_property(bot_card, "rotation", 0.0, 0.25).set_delay(0.22)
	tw2.tween_property(bot_card, "scale", STACK_CONFIGS[0]["scale"], 0.25).set_delay(0.22)
	tw2.tween_property(bot_card, "modulate:a", STACK_CONFIGS[0]["alpha"], 0.25).set_delay(0.22)

	tw2.chain().tween_callback(func() -> void:
		# Shift order: [2, 0, 1]
		_top_order = [bot_card_idx, top_card_idx, mid_card_idx]
		_is_animating = false
		_update_page_indicator()
	)


func _apply_stack_positions_instant() -> void:
	for slot in range(3):
		var card_idx := _top_order[slot]
		var card := card_nodes[card_idx]
		if card != null:
			card.position = STACK_CONFIGS[slot]["pos"]
			card.scale = STACK_CONFIGS[slot]["scale"]
			card.z_index = STACK_CONFIGS[slot]["z"]
			card.modulate.a = STACK_CONFIGS[slot]["alpha"]
			card.rotation = 0.0


func _update_page_indicator() -> void:
	if page_indicator != null:
		var current_letter_num := _top_order[0] + 1
		page_indicator.text = "信件 %d / 3" % current_letter_num
