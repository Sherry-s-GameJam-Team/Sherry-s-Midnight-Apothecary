# Potion direct hits

Every thrown bottle is a `PotionProjectile` (`res://shared/potions/runtime/potion_projectile.gd`). When its `CharacterBody2D` collides with a physics body in `PotionThrowTuning.projectile_collision_mask`, it breaks at the contact point and walks from the collided node up through its parents to find `receive_potion_hit(hit: Dictionary)`.

首次进入药水瞄准时，顶部 HintUI 显示“按住鼠标左键瞄准，松开即可投掷药水。”；`tutorial_throw_potion` 仅作为存档去重键，不会显示给玩家。

An enemy can put its collision shape on its root body, or on a child physics body below that root. The receiver method may live on either node or any ancestor.

```gdscript
func receive_potion_hit(hit: Dictionary) -> void:
	var potion_id: StringName = hit.potion_id
	var point: Vector2 = hit.impact_point
	# Apply health, stagger, reactions, or AI state here.
```

`hit` contains `potion`, `potion_id`, a copied `payload`, `impact_point`, `impact_normal`, and `projectile`. `PotionProjectile.direct_hit(receiver, hit)` is emitted after the receiver is called.

Direct collision is distinct from the splash effect: the existing `PotionEffectExecutor` still performs its circular `effect_radius` query and calls `apply_potion_effect(effect_id, context)` for compatible targets. An enemy that needs both direct impact and area effects can implement both methods.

For an enemy to receive direct hits, ensure its physics body's collision layer overlaps `PotionThrowTuning.projectile_collision_mask` (currently layer 1 by default). The projectile itself has collision layer 0, so it does not act as an obstacle for other bodies.
