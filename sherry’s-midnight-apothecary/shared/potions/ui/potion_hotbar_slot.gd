class_name PotionHotbarSlot
extends Control

@export var circle_radius := 30.0
@export var ring_radius := 33.5
@export var ring_width := 4.5
@export var ring_background_color := Color(0.12, 0.1, 0.16, 0.9)
@export var empty_background_color := Color(0.1, 0.09, 0.12, 0.82)
@export var filled_background_color := Color(0.16, 0.13, 0.2, 0.9)
@export var selected_outline_color := Color(1.0, 0.82, 0.34, 1.0)
@export var empty_bottle_tint := Color(0.3, 0.3, 0.34, 0.72)

@onready var button: Button = %Button
@onready var bottle_view: TextureRect = %BottleView
@onready var key_label: Label = %KeyLabel
@onready var dose_label: Label = %DoseLabel

var capacity_ratio := 0.0
var ring_color := Color(0.55, 0.5, 0.62, 0.9)
var bottle_texture: Texture2D
var is_selected := false
var is_equipped := false
var is_insufficient := false


func _ready() -> void:
	queue_redraw()


func set_display(
	texture: Texture2D,
	configured_capacity_ratio: float,
	configured_ring_color: Color,
	configured_selected: bool,
	configured_equipped: bool,
	configured_insufficient: bool,
	configured_tooltip: String
) -> void:
	bottle_texture = texture
	bottle_view.texture = texture
	capacity_ratio = clampf(configured_capacity_ratio, 0.0, 1.0)
	ring_color = configured_ring_color
	is_selected = configured_selected
	is_equipped = configured_equipped
	is_insufficient = configured_insufficient
	button.icon = texture
	button.tooltip_text = configured_tooltip
	button.disabled = not configured_equipped
	button.set_pressed_no_signal(configured_selected)
	dose_label.text = "%d%%" % roundi(capacity_ratio * 100.0) if configured_equipped else "空"
	bottle_view.modulate = Color.WHITE if configured_equipped else empty_bottle_tint
	if configured_equipped and configured_insufficient:
		bottle_view.modulate = Color(0.62, 0.62, 0.66, 0.88)
	queue_redraw()


func set_slot_number(slot_number: int) -> void:
	key_label.text = str(slot_number)


func _draw() -> void:
	var center := size * 0.5
	var background := filled_background_color if is_equipped else empty_background_color
	draw_circle(center, circle_radius, background)
	draw_arc(center, ring_radius, 0.0, TAU, 72, ring_background_color, ring_width, true)
	if is_equipped and capacity_ratio > 0.0:
		var active_color := ring_color.darkened(0.34) if is_insufficient else ring_color
		draw_arc(center, ring_radius, -PI * 0.5, -PI * 0.5 + TAU * capacity_ratio, 72, active_color, ring_width, true)
	if is_selected:
		draw_arc(center, ring_radius + 3.5, 0.0, TAU, 72, selected_outline_color, 2.5, true)
