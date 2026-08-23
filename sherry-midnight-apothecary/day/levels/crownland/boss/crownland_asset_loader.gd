class_name CrownlandAssetLoader
extends Node
## 美术资源自动加载器 / Crownland Art Asset Loader
##
## Reads PNGs from the three stage frame directories and the art/ folder,
## then injects them into the BattleDirector and Boss AnimatedSprite2D
## at runtime. This avoids the need to assign every texture manually
## in the Godot Inspector.
##
## Art layout expected:
##   res://day/levels/crownland/boss/art/        ← attack / FX PNGs
##   res://day/levels/crownland/boss/stage_1_invulnerable_barrage/   ← boss idle frames Ph1
##   res://day/levels/crownland/boss/stage_2_black_pillars/          ← boss idle frames Ph2
##   res://day/levels/crownland/boss/stage_3_black_crown_finisher/   ← boss frames Ph3
##
## Attach this node as a child of CrownlandBossArena.
## It runs once in _ready() and then removes itself from the process loop.

# ─── Known art filenames (update if actual filenames differ) ───
# All paths are relative to res://day/levels/crownland/boss/art/
const ART_BASE := "res://day/levels/crownland/boss/art/"

const ART_ARROW        := ART_BASE + "半扇展开箭矢.png"
const ART_MAGIC_CIRCLE := ART_BASE + "魔法阵.png"
const ART_PILLAR       := "res://day/levels/crownland/pillar.png"
const ART_PILLAR_BROKEN:= ART_BASE + "破碎的黑魔法柱子.png"
const ART_SWORD        := ART_BASE + "魔剑右向.png"
const ART_SWORD_QI     := ART_BASE + "右向剑气.png"
const ART_ORB_SMALL    := ART_BASE + "左向弹幕小.png"
const ART_ORB_MEDIUM   := ART_BASE + "左向弹幕中.png"
const ART_ORB_LARGE    := ART_BASE + "左向弹幕1.png"
const ART_NEEDLE_1     := ART_BASE + "竖向两面针.png"
const ART_NEEDLE_2     := ART_BASE + "竖向两面针2.png"
const ART_NEEDLE_3     := ART_BASE + "竖向两面针3.png"
const ART_EXPLO_1      := ART_BASE + "爆破帧1.png"
const ART_EXPLO_2      := ART_BASE + "爆破帧2.png"
const ART_EXPLO_3      := ART_BASE + "爆破帧3.png"
const ART_EXPLO_4      := ART_BASE + "爆破帧4.png"

# ─── Stage frame directories ───
const STAGE1_DIR := "res://day/levels/crownland/boss/stage_1_invulnerable_barrage/"
const STAGE2_DIR := "res://day/levels/crownland/boss/stage_2_black_pillars/"
const STAGE3_DIR := "res://day/levels/crownland/boss/stage_3_black_crown_finisher/"

# AnimatedSprite2D animation names mapped to which directory to load from
# Each entry: { "anim": StringName, "dir": String, "fps": float, "loop": bool }
const ANIM_MAPPING: Array[Dictionary] = [
	{ "anim": "phase1_idle", "dir": STAGE1_DIR, "fps": 12.0, "loop": true },
	# Phase 2 is a one-shot corruption reveal. It intentionally holds its final
	# frame while CrownlandBoss supplies the separate hovering motion.
	{ "anim": "phase2_idle", "dir": STAGE2_DIR, "fps": 12.0, "loop": false },
	{ "anim": "phase3_idle", "dir": STAGE3_DIR, "fps": 12.0, "loop": true },
	{ "anim": "transition",  "dir": STAGE2_DIR, "fps": 12.0, "loop": false },
	{ "anim": "phase3_enter","dir": STAGE3_DIR, "fps": 12.0, "loop": false },
	{ "anim": "dying",       "dir": STAGE3_DIR, "fps": 10.0, "loop": false },
	{ "anim": "purified",    "dir": STAGE3_DIR, "fps": 8.0,  "loop": true },
]


func _ready() -> void:
	# Wait one frame to let all nodes finish _ready
	await get_tree().process_frame
	_inject_all()


func _inject_all() -> void:
	var arena := get_parent() as CrownlandBossArena
	if arena == null:
		push_warning("CrownlandAssetLoader: parent is not CrownlandBossArena, skipping.")
		return

	var director := arena.get_node_or_null("BattleDirector") as CrownlandBattleDirector
	var boss     := arena.get_node_or_null("Boss") as CrownlandBoss
	var pillars  := arena.get_node_or_null("Pillars")

	_inject_director_textures(director)
	_inject_boss_animations(boss)
	_inject_pillar_textures(pillars)

	print("[CrownlandAssetLoader] Asset injection complete.")


# ─── Director texture injection ───

func _inject_director_textures(dir: CrownlandBattleDirector) -> void:
	if dir == null:
		return

	dir.tex_arrow         = _load_tex(ART_ARROW)
	dir.tex_magic_circle  = _load_tex(ART_MAGIC_CIRCLE)
	dir.tex_pillar_intact = _load_tex(ART_PILLAR)
	dir.tex_pillar_broken = _load_tex(ART_PILLAR_BROKEN)
	dir.tex_sword         = _load_tex(ART_SWORD)
	dir.tex_sword_qi      = _load_tex(ART_SWORD_QI)
	dir.tex_orb_small     = _load_tex(ART_ORB_SMALL)
	dir.tex_orb_medium    = _load_tex(ART_ORB_MEDIUM)
	dir.tex_orb_large     = _load_tex(ART_ORB_LARGE)

	# Needle variants
	var needle_arr: Array[Texture2D] = []
	for p: String in [ART_NEEDLE_1, ART_NEEDLE_2, ART_NEEDLE_3]:
		var t := _load_tex(p)
		if t != null:
			needle_arr.append(t)
	dir.tex_needle = needle_arr

	# Explosion frames
	var explo_arr: Array[Texture2D] = []
	for p: String in [ART_EXPLO_1, ART_EXPLO_2, ART_EXPLO_3, ART_EXPLO_4]:
		var t := _load_tex(p)
		if t != null:
			explo_arr.append(t)
	dir.tex_explosion = explo_arr


# ─── Boss AnimatedSprite2D frame injection ───

func _inject_boss_animations(boss: CrownlandBoss) -> void:
	if boss == null:
		return
	var sprite := boss.get_node_or_null("VisualRoot/AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		push_warning("CrownlandAssetLoader: AnimatedSprite2D not found on Boss.")
		return

	var frames := sprite.sprite_frames
	if frames == null:
		frames = SpriteFrames.new()
		sprite.sprite_frames = frames

	for mapping: Dictionary in ANIM_MAPPING:
		var anim_name: StringName = StringName(mapping["anim"])
		var dir_path: String = mapping["dir"]
		var fps: float = mapping["fps"]
		var loop: bool = mapping["loop"]

		# Collect frames from directory
		var tex_list := _load_directory_frames(dir_path)
		if tex_list.is_empty():
			# Keep the empty animation slot — no error
			continue

		# Ensure animation exists
		if not frames.has_animation(anim_name):
			frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, fps)
		frames.set_animation_loop(anim_name, loop)

		# Clear existing frames and add new ones
		frames.clear(anim_name)
		for tex: Texture2D in tex_list:
			frames.add_frame(anim_name, tex)

	# Ensure idle fallback exists
	if not frames.has_animation(&"idle"):
		frames.add_animation(&"idle")
		frames.set_animation_speed(&"idle", 12.0)
		frames.set_animation_loop(&"idle", true)
		# Copy phase1_idle frames as idle fallback
		if frames.has_animation(&"phase1_idle"):
			var count := frames.get_frame_count(&"phase1_idle")
			for i: int in range(count):
				frames.add_frame(&"idle", frames.get_frame_texture(&"phase1_idle", i))


# ─── Pillar texture injection ───

func _inject_pillar_textures(pillars: Node) -> void:
	if pillars == null:
		return
	var intact  := _load_tex(ART_PILLAR)
	var broken  := _load_tex(ART_PILLAR_BROKEN)
	var explo_frames: Array[Texture2D] = []
	for p: String in [ART_EXPLO_1, ART_EXPLO_2, ART_EXPLO_3, ART_EXPLO_4]:
		var t := _load_tex(p)
		if t != null:
			explo_frames.append(t)

	for child: Node in pillars.get_children():
		if child is CrownlandMagicPillar:
			var p := child as CrownlandMagicPillar
			if intact != null:
				p.intact_texture = intact
			if broken != null:
				p.broken_texture = broken
			if not explo_frames.is_empty():
				p.explosion_frame_textures = explo_frames
			p.refresh_visual_texture()


# ─── Utilities ───

## Load a texture with a graceful warning (no crash) if file is missing.
func _load_tex(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		push_warning("CrownlandAssetLoader: missing texture '%s' — skipping." % path)
		return null
	return load(path) as Texture2D


## Load all PNG frames from a directory, sorted alphabetically.
## Returns empty array if directory does not exist or has no PNGs.
func _load_directory_frames(dir_path: String) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return result

	var files: Array[String] = []
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".png"):
			files.append(dir_path + fname)
		fname = dir.get_next()
	dir.list_dir_end()

	files.sort()   # alphabetical = frame order
	for fpath: String in files:
		var t := _load_tex(fpath)
		if t != null:
			result.append(t)
	return result
