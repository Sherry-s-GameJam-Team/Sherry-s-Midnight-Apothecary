class_name CrownlandBossLevel
extends DayLevelEnvironment

## Standalone 王畿 Boss 关卡入口。
## The scene owns the standard daytime player, camera and collision boundary
## contract; CrownlandBossArena owns only the encounter itself.

@onready var arena: CrownlandBossArena = $CrownlandBossArena
@onready var trigger: Area2D = $BossTrigger
@onready var status_label: Label = $UI/StatusPanel/Status

var _battle_started := false
var _boss_defeated := false


func _ready() -> void:
	super._ready()
	trigger.body_entered.connect(_on_boss_trigger_body_entered)
	arena.boss_started.connect(_on_boss_started)
	arena.boss_defeated.connect(_on_boss_defeated)
	_set_status("踏入王座之间，靠近王冠残影以开始战斗。")


func _on_boss_trigger_body_entered(body: Node2D) -> void:
	if _battle_started or _boss_defeated:
		return
	if body != $Player and not body.is_in_group("player"):
		return
	_battle_started = true
	trigger.set_deferred("monitoring", false)
	arena.trigger_boss_battle(body)


func _on_boss_started() -> void:
	_set_status("王冠的黑魔法苏醒了。摧毁黑柱，净化国王。")


func _on_boss_defeated(_boss_id: StringName) -> void:
	_boss_defeated = true
	_set_status("王畿已重获光明。")


## Preserve the shared health contract, while giving the local player the
## standard hit animation and a short knockback from the arena centre.
func apply_player_damage(amount: int, source: StringName = &"") -> bool:
	var player := get_node_or_null("Player") as Node2D
	if player != null and player.has_method("play_hazard_hit"):
		var direction := signf(player.global_position.x - arena.global_position.x)
		if is_zero_approx(direction):
			direction = -1.0
		player.call("play_hazard_hit", Vector2(direction * 140.0, -160.0))
	return super.apply_player_damage(amount, source)


func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text
