# Crimson Aqueduct

Godot 4.6 的自包含 2D 鼠标小游戏。模块不依赖玩家节点、`PlayerData` 或主游戏运行时。

## 接入

```gdscript
const CRIMSON_AQUEDUCT := preload("res://minigames/crimson_aqueduct/scenes/crimson_aqueduct_root.tscn")

func open_crimson_aqueduct() -> void:
	var game := CRIMSON_AQUEDUCT.instantiate()
	game.setup({
		"level_id": &"standard",
		"purifier_potions": 3,
		"sealant_potions": 2,
	})
	game.minigame_completed.connect(_on_crimson_aqueduct_completed.bind(game))
	game.minigame_failed.connect(_on_crimson_aqueduct_failed.bind(game))
	game.minigame_exited.connect(_on_crimson_aqueduct_exited.bind(game))
	add_child(game)

func _on_crimson_aqueduct_completed(result: Dictionary, game: Node) -> void:
	print(result)
	game.queue_free()
```

`setup()` 可在 `add_child()` 前后调用。完成和失败时模块停止模拟并发出一次结果信号；退出、完成或失败后如何切换上级场景由宿主决定。

## 配置

支持 `tutorial`、`standard`、`hard` 三种 `level_id`，以及 `purifier_potions`、`sealant_potions`、`safe_pollution_threshold`、`minimum_clean_supply` 和 `stability_duration`。关卡没有倒计时或污染失败状态；玩家可持续调整机关，直到安全供水稳定并完成解密。

视觉由命名明确的占位节点构成。正式美术可以替换根场景的 `Architecture`、各机关场景的视觉子节点以及 UI 样式，而无需修改管网和结算逻辑。
