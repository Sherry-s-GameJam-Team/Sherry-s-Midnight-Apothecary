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
	"jump_takeoff": {
		"directory": "07_jump",
		"prefix": "jump",
		"padding": 4,
		"first": 1,
		"last": 10,
		"fps": 30.0,
		"loop": false,
		"scale_multiplier": 0.5085,
		"faces_right_by_default": true,
	},
	"jump_fall": {
		"directory": "07_jump",
		"prefix": "jump",
		"padding": 4,
		"first": 11,
		"last": 24,
		"fps": 24.0,
		"loop": true,
		"scale_multiplier": 0.5085,
		"faces_right_by_default": true,
	},
	"land": {
		"directory": "08_land",
		"prefix": "land",
		"padding": 4,
		"frame_numbers": [1, 2, 6, 7, 9, 10, 11, 12],
		"fps": 20.0,
		"loop": false,
		"scale_multiplier": 0.5085,
		"faces_right_by_default": true,
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
		if action.has("frame_numbers"):
			for frame_number: int in action["frame_numbers"]:
				_add_frame(sprite_frames, action_name, action, frame_number)
		else:
			_add_frame_range(sprite_frames, action_name, action, action["first"], action["last"], 1)


static func _add_frame_range(sprite_frames: SpriteFrames, action_name: String, action: Dictionary, first: int, last: int, step: int) -> void:
	var frame_number := first
	while (step > 0 and frame_number <= last) or (step < 0 and frame_number >= last):
		_add_frame(sprite_frames, action_name, action, frame_number)
		frame_number += step


static func _add_frame(sprite_frames: SpriteFrames, action_name: String, action: Dictionary, frame_number: int) -> void:
	var padding: int = action.get("padding", 3)
	var path := "res://art/characters/sherry/frames/%s/%s_%s.png" % [action["directory"], action["prefix"], str(frame_number).pad_zeros(padding)]
	var frame := load(path) as Texture2D
	if frame == null:
		push_error("Sherry animation frame is missing: %s" % path)
		return
	sprite_frames.add_frame(action_name, frame)
