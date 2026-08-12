extends RefCounted

const TEMPERATURE_GAUGE_SCENE := preload("res://night/alchemy/heat/temperature_gauge.tscn")


static func run(test: TestSupport) -> void:
	var gauge := TEMPERATURE_GAUGE_SCENE.instantiate() as TemperatureGauge
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child(gauge)
	var needle := gauge.get_node("TemperatureNeedle") as TextureRect
	var ranges := gauge.get_node("TemperatureRanges") as TemperatureRangeOverlay

	test.expect(needle != null, "Temperature gauge keeps the needle as an editable scene node.")
	test.expect(ranges != null, "Temperature gauge exposes temperature ranges as an editable scene node.")
	test.expect(not gauge.auto_layout_needle, "Manual needle placement is preserved instead of being overwritten by script layout.")
	test.expect(ranges.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Range overlay remains visual-only in the brewing scene.")
	test.expect(ranges.size.x > 0.0 and ranges.size.y > 0.0, "Range overlay has an editor-adjustable visible rectangle.")
	var needle_hub := needle.position + needle.pivot_offset
	var dial_center := ranges.position + ranges.size * 0.5
	test.expect_float_close(needle_hub.x, dial_center.x, 0.01, "Needle hub aligns with the dial center horizontally.")
	test.expect_float_close(needle_hub.y, dial_center.y, 0.01, "Needle hub aligns with the dial center vertically.")
	gauge.free()
