class_name SherryAnimationLibrary
extends RefCounted

## Sherry 的动作清单。每个条目只记录连续贴图的目录与编号范围。
## 更换帧时不需要修改控制器；新增动作时在 ACTIONS 增加一个条目即可。

const ACTIONS := {
	"idle": {
		"directory": "01_idle",
		"prefix": "idle",
		"first": 1,
		"last": 24,
		"fps": 12.0,
		"loop": true,
	},
	"walk": {
		"directory": "02_walk",
		"prefix": "walk",
		"first": 3,
		"last": 33,
		"fps": 14.0,
		"loop": true,
	},
	"run": {
		"directory": "03_run",
		"prefix": "run",
		"first": 10,
		"last": 23,
		"fps": 16.0,
		"loop": true,
	},
	"throw": {
		"directory": "04_throw",
		"prefix": "hit",
		"first": 0,
		"last": 5,
		"fps": 14.0,
		"loop": false,
	},
	"hit": {
		"directory": "05_hit",
		"prefix": "hit",
		"first": 6,
		"last": 19,
		"fps": 48.0,
		"loop": false,
	},
	"fall": {
		"directory": "06_fall",
		"prefix": "fall",
		"first": 0,
		"last": 24,
		"fps": 14.0,
		"loop": false,
	},
}


static func install_into(sprite_frames: SpriteFrames) -> void:
	for action_name: String in ACTIONS:
		if sprite_frames.has_animation(action_name):
			sprite_frames.remove_animation(action_name)
		sprite_frames.add_animation(action_name)
		var action: Dictionary = ACTIONS[action_name]
		sprite_frames.set_animation_speed(action_name, action["fps"])
		sprite_frames.set_animation_loop(action_name, action["loop"])
		_add_frame_range(sprite_frames, action_name, action, action["first"], action["last"], 1)


static func _add_frame_range(sprite_frames: SpriteFrames, action_name: String, action: Dictionary, first: int, last: int, step: int) -> void:
	var frame_number := first
	while (step > 0 and frame_number <= last) or (step < 0 and frame_number >= last):
		var path := "res://art/characters/sherry/frames/%s/%s_%03d.png" % [action["directory"], action["prefix"], frame_number]
		var frame := load(path) as Texture2D
		if frame == null:
			push_error("Sherry animation frame is missing: %s" % path)
			return
		sprite_frames.add_frame(action_name, frame)
		frame_number += step
